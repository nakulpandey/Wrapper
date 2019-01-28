//
//  ProxyServer.m
//  Wrapper
//
//  Created by Stephen Ayers on 8/25/17.
//  Copyright © 2017 Stephen Ayers. All rights reserved.
//

#import "ProxyServer.h"

@interface ProxyServer ()

@property (nonatomic, strong) NSURLSession *session;

@property (nonatomic, strong) NSMutableDictionary *responseHandler;


@end


@implementation ProxyServer

- (instancetype)init {
    self = [super init];
    if (self) {
        NSURLSessionConfiguration *config = [NSURLSessionConfiguration ephemeralSessionConfiguration];
        self.session = [NSURLSession sessionWithConfiguration:config];
        
        self.startTime = [NSDate date];
        self.responseHandler = [NSMutableDictionary dictionary];
        
        [self loadInitialFilesToServeInMemory];
        
        __weak typeof(self) weakSelf = self;
        
        self.requestQueue = [NSMutableArray new];
        
        self.webServer = [[GCDWebServer alloc] init];
        
        
        
        // Add a handler to respond to GET requests on any URL
        [self.webServer addDefaultHandlerForMethod:@"GET" requestClass:[GCDWebServerRequest class] asyncProcessBlock:^(__kindof GCDWebServerRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            [strongSelf handleRequest:request completion:completionBlock];
        }];
        
        [self.webServer addDefaultHandlerForMethod:@"POST" requestClass:[GCDWebServerDataRequest class] asyncProcessBlock:^(__kindof GCDWebServerDataRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
            if([request.URL.absoluteString containsString:@"InstrumentationBeacon.sendData"]){
                self.endTime = [NSDate date];
                NSTimeInterval timeInterval = [self.endTime timeIntervalSinceDate:self.startTime];
                NSLog(@"-------COMMUNITY LOADED IN--- %f seconds", timeInterval);
                [self checkForConsistency];
            }
            __strong typeof(weakSelf) strongSelf = weakSelf;
            [strongSelf handleRequest:request completion:completionBlock];
        }];
        
    }
    return self;
}

- (void)handleRequest:(__kindof GCDWebServerRequest * _Nonnull)request completion:(GCDWebServerCompletionBlock  _Nonnull)completionBlock {
    
    NSString *urlString = nil;
    NSError *error = nil;
    NSMutableURLRequest *newRequest = [NSMutableURLRequest new];
    urlString = [@"https://sdodemo-main-14f0402cabc-150-163dbf47510.force.com/" stringByAppendingString: [request.URL.absoluteString substringFromIndex:[request.URL.baseURL.absoluteString length]]];
    newRequest.URL = [NSURL URLWithString:urlString];
    newRequest.HTTPMethod = request.method;
    newRequest.allHTTPHeaderFields = request.headers;
    [newRequest setValue:@"sdodemo-main-14f0402cabc-150-163dbf47510.force.com" forHTTPHeaderField:@"Host"];
    [newRequest setValue:@"https://sdodemo-main-14f0402cabc-150-163dbf47510.force.com" forHTTPHeaderField:@"Origin"];
    [newRequest setValue:@"https://sdodemo-main-14f0402cabc-150-163dbf47510.force.com" forHTTPHeaderField:@"Referer"];
    NSHTTPURLResponse *response = nil;
    if ([request isKindOfClass:[GCDWebServerDataRequest class]]) {
        newRequest.HTTPBody = [(GCDWebServerDataRequest*)request data];
    }
    [self stampCookieHeaderToRequest:newRequest];
    
    NSString *lastExtension = newRequest.URL.lastPathComponent;
    NSString *fileName = [self getFileNameRequestPath:lastExtension];
    NSData *fileContent = nil;
    if([self fileExists:fileName]) {
        fileContent  = [[self responseHandler] valueForKey:fileName];
    }
    if([self canServeTheRequestFromFile: fileName] && fileContent!=nil) {
        GCDWebServerDataResponse *finalResponse = nil;
        if([newRequest.URL.pathExtension isEqualToString:@""]) {
            finalResponse = [GCDWebServerDataResponse responseWithHTML: [[NSString alloc] initWithData:fileContent encoding:NSUTF8StringEncoding]];
            [finalResponse setCacheControlMaxAge:0];
        }
        else if([newRequest.URL.pathExtension containsString:@"css"]) {
            finalResponse = [GCDWebServerDataResponse responseWithData:fileContent contentType:@"text/css;charset=UTF-8"];
            [finalResponse setCacheControlMaxAge:0];
        }
        else if([newRequest.URL.pathExtension containsString:@"js"]) {
            finalResponse = [GCDWebServerDataResponse responseWithData:fileContent contentType:@"text/javascript;charset=UTF-8"];
            [finalResponse setCacheControlMaxAge:0];
        }
        NSLog(@"SERVED THE CAHCED RESPONSE for %@", fileName);
        completionBlock(finalResponse);
        // Update the server cache
        if([fileName isEqualToString:@"index.html"]) {
            [self.requestQueue addObject:newRequest];
        }
        
    }else {
        NSData *responseData = [NSURLConnection sendSynchronousRequest:newRequest returningResponse:&response error:&error];
        NSLog(@" [%@] REQUEST SENT with path ../%@",newRequest.HTTPMethod, [newRequest.URL.absoluteString substringFromIndex: [newRequest.URL.absoluteString length] - 15]);
        
        NSString *serverResponse = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
        if([serverResponse containsString:@"markup://aura:clientOutOfSync"]) {
            [self removeFile:@"index.html"];
            [self handleOutOfSync];
            return;
        }
        
        if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
            if([self canServeTheRequestFromFile:fileName]){
                if([self areTwoDataequal:responseData dataSecond:[self getContentOfTheFile:fileName]]) {
                    NSLog(@"No need to update the data as the data is identical");
                }else {
                    [self saveFile:fileName contentData:responseData];
                }
            }
            NSLog(@"[%@] REQUEST SERVED for path ../%@",newRequest.HTTPMethod,  [newRequest.URL.absoluteString substringFromIndex: [newRequest.URL.absoluteString length] - 15]);
            GCDWebServerDataResponse *finalResponse = [GCDWebServerDataResponse responseWithData:responseData contentType:response.MIMEType];
            [self updateCookies:response];
            completionBlock(finalResponse);
        }
        else
        {
            NSLog(@"Didn't get a correct URL response for some reason %@", error);
            completionBlock([GCDWebServerDataResponse responseWithData:responseData contentType:response.MIMEType]);
        }
    }
}

- (NSURL *)startProxy
{
    // Start server on port 8080
    [self.webServer startWithPort:8080 bonjourName:nil];
    NSLog(@"Visit %@ in your web browser", self.webServer.serverURL);
    
    return (self.webServer.serverURL);
}

- (NSURL *)serverURL
{
    return self.webServer.serverURL;
}

-(void) saveFile: (NSString *)fileName contentData: (NSData *)data
{
    NSString *pathAndFileName = [[NSBundle mainBundle] pathForResource:fileName ofType:nil];
    [data writeToFile:pathAndFileName atomically:YES];
}

-(NSData *) getContentOfTheFile: (NSString *) fileName
{
    if(![self fileExists:fileName]) {
        return nil;
    }
    NSString *pathAndFileName = [[NSBundle mainBundle] pathForResource:fileName ofType:nil];
    NSData *urlData = [NSData dataWithContentsOfFile:pathAndFileName];
    return urlData;
}

-(BOOL) fileExists: (NSString *) fileName
{
    NSString *pathAndFileName = [[NSBundle mainBundle] pathForResource:fileName ofType:nil];
    return [[NSFileManager defaultManager] fileExistsAtPath:pathAndFileName];
}


-(BOOL) canServeTheRequestFromFile: (NSString *) fileName
{
    return ![fileName isEqualToString:@""];
}


-(void) loadInitialFilesToServeInMemory
{
    [self.responseHandler setValue:[self getContentOfTheFile:@"index.html"] forKey:@"index.html"];
    [self.responseHandler setValue:[self getContentOfTheFile:@"app.css"] forKey:@"app.css"];
    [self.responseHandler setValue:[self getContentOfTheFile:@"fonts.css"] forKey:@"fonts.css"];
    [self.responseHandler setValue:[self getContentOfTheFile:@"inline.js"] forKey:@"inline.js"];
    [self.responseHandler setValue:[self getContentOfTheFile:@"app.js"] forKey:@"app.js"];
    [self.responseHandler setValue:[self getContentOfTheFile:@"resources.js"] forKey:@"resources.js"];
    [self.responseHandler setValue:[self getContentOfTheFile:@"bootstrap.js"] forKey:@"bootstrap.js"];
}

-(NSString *) getFileNameRequestPath: (NSString *) path
{
    if([path isEqualToString:@"s"]){
        return @"index.html";
    }
    else if ([path isEqualToString:@"app.css"]) {
        return @"app.css";
    }
    else if ([path isEqualToString:@"fonts.css"]) {
        return @"fonts.css";
    }
    else if ([path isEqualToString:@"inline.js"]) {
        return @"inline.js";
    }
    else if ([path isEqualToString:@"app.js"]) {
        return @"app.js";
    }
    else if ([path isEqualToString:@"resources.js"]) {
        return @"resources.js";
    }
    else if ([path isEqualToString:@"bootstrap.js"]) {
        return @"bootstrap.js";
    }else {
        return @"";
    }
    
}


-(BOOL) areTwoDataequal: (NSData *) dataOne dataSecond:(NSData *) dataTwo
{
    return [dataOne isEqualToData:dataTwo];
}

-(void) checkForConsistency
{
    int i;
    int count = [self.requestQueue count];
    for (i = 0; i < count; i++) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
            NSMutableURLRequest *request = [self.requestQueue objectAtIndex: i];
            NSString *fileName = [self getFileNameRequestPath: request.URL.lastPathComponent];
            NSURLSessionDataTask *task = [self.session dataTaskWithRequest: request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
                if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
                    [self updateCookies:response];
                    if([self canServeTheRequestFromFile: fileName] ){
                        [self saveFile:@"temp" contentData:data];
                        NSFileManager *filemgr;
                        
                        filemgr = [NSFileManager defaultManager];
                        if([self areTwoDataequal:data dataSecond:[self getContentOfTheFile:fileName]]) {
                            NSLog(@"BASE DOCUMENT : %@ IS UP TO DATE", fileName);
                        }else {
                            if([fileName isEqualToString:@"index.html"]) {
                                [self saveFile:fileName contentData:data];
                                [self handleOutOfSync];
                            }
                        }
                    }
                }
            }];
            [task resume];
        });
        
    }
}

-(void) handleOutOfSync
{
    NSLog(@"Upadting the cache and removing all the stale files!!!");
    [self removeFile:@"app.css"];
    [self removeFile:@"resources.js"];
    [self removeFile:@"inline.js"];
    [self removeFile:@"fonts.css"];
    [self removeFile:@"bootstrap.js"];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"MyCacheUpdatedNotification" object:self];
}

-(void) removeFile : (NSString*) fileName
{
     NSString *pathAndFileName = [[NSBundle mainBundle] pathForResource:fileName ofType:nil];
    NSError *error = nil;
    [[NSFileManager defaultManager] removeItemAtPath:pathAndFileName error:&error];
}

-(void) stampCookieHeaderToRequest: (NSMutableURLRequest *) request
{
    NSMutableDictionary *dic =  [[NSMutableDictionary alloc] init];
    NSMutableArray *array = [NSMutableArray array];
    for (NSHTTPCookie *cookie in [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookies]) {
        NSString *value = [NSString stringWithFormat:@"%@=%@", cookie.name, cookie.value];
        [array addObject:value];
    }
    NSString *header = [array componentsJoinedByString:@";"];
    NSString *finalCookieString = @"";
    for(id key in dic.allKeys) {
        NSString *cookieVal = [[key stringByAppendingString:@"="] stringByAppendingString:[ dic valueForKey:key]];
        finalCookieString = [[finalCookieString stringByAppendingString:cookieVal] stringByAppendingString:@"; "];
    }
    
    if([finalCookieString length]>0) {
        finalCookieString = [finalCookieString substringToIndex:[finalCookieString length]-2];
    }
    [request setValue:finalCookieString forHTTPHeaderField:@"Cookie"];
   }


-(void) updateCookies: (NSHTTPURLResponse *) response
{
            NSArray *cookies = [NSHTTPCookie cookiesWithResponseHeaderFields:[response allHeaderFields] forURL:[NSURL URLWithString:@""]];
            for (NSHTTPCookie *cookie in cookies) {
                NSMutableDictionary* cookieProperties = [NSMutableDictionary dictionary];
                //set rest of the properties
                [cookieProperties setObject:[cookie name] forKey:NSHTTPCookieName];
                [cookieProperties setObject:[cookie value] forKey:NSHTTPCookieValue];
                [cookieProperties setObject:[cookie path] forKey:NSHTTPCookiePath];
                NSDate* expiryDate = [[NSDate date] dateByAddingTimeInterval:2629743];
                [cookieProperties setObject:expiryDate forKey:NSHTTPCookieExpires];
                NSHTTPCookie *newCookie = [NSHTTPCookie cookieWithProperties:cookieProperties];
                [[NSHTTPCookieStorage sharedHTTPCookieStorage] setCookie:newCookie];
            }
}

@end
