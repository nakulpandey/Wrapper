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
        //        NSURLSessionConfiguration *config = [NSURLSessionConfiguration ephemeralSessionConfiguration];
        //        self.session = [NSURLSession sessionWithConfiguration:config];
        
        __weak typeof(self) weakSelf = self;
        
        self.webServer = [[GCDWebServer alloc] init];
        
        self.responseHandler = [NSMutableDictionary dictionary];
        
        // Add a handler to respond to GET requests on any URL
        [self.webServer addDefaultHandlerForMethod:@"GET" requestClass:[GCDWebServerRequest class] asyncProcessBlock:^(__kindof GCDWebServerRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
            NSLog(@"-------REQUESTED GET CALL --- %@", request.URL);
            __strong typeof(weakSelf) strongSelf = weakSelf;
            [strongSelf handleRequest:request completion:completionBlock];
        }];
        
        [self.webServer addDefaultHandlerForMethod:@"POST" requestClass:[GCDWebServerDataRequest class] asyncProcessBlock:^(__kindof GCDWebServerDataRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
            NSLog(@"-------REQUESTED POST CALL --- %@", request.URL);
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
    
    
    NSString *lastExtension = newRequest.URL.lastPathComponent;
    NSString *fileName = [self getFileNameFromPath:lastExtension];
    
    NSLog(@"--------------- [%@] => [%@]", lastExtension, fileName);
    
    NSData *fileContent = nil;
    if([self fileExists:fileName]) {
      fileContent  = [self getContentOfTheFile:fileName];
    }
    if([self canHandleRequest: fileName] && fileContent!=nil) {
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
        // Update the server cache
        NSData *responseData = [NSURLConnection sendSynchronousRequest:newRequest returningResponse:&response error:&error];
        if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
            
            if([self canHandleRequest:fileName] ){
                if([self areTwoDataequal:responseData dataSecond:[self getContentOfTheFile:fileName]]) {
                    NSLog(@"NO need to update the data as the data is identical");
                }else {
                    [self saveFile:fileName contentData:responseData];
                }
            }
        }
        else
        {
            NSLog(@"Didn't get a correct URL response for some reason %@", error);
            completionBlock([GCDWebServerDataResponse responseWithData:responseData contentType:response.MIMEType]);
        }
        completionBlock(finalResponse);
    }else {
        NSData *responseData = [NSURLConnection sendSynchronousRequest:newRequest returningResponse:&response error:&error];
        if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
            if([self canHandleRequest:fileName]){
                
                if([self areTwoDataequal:responseData dataSecond:[self getContentOfTheFile:fileName]]) {
                    NSLog(@"NO need to update the data as the data is identical");
                }else {
                    [self saveFile:fileName contentData:responseData];
                }
                
                
            }
            GCDWebServerDataResponse *finalResponse = [GCDWebServerDataResponse responseWithData:responseData contentType:response.MIMEType];
            [finalResponse setCacheControlMaxAge:0];
            [self.responseHandler setValue:finalResponse forKey:request.URL.absoluteString];
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
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSArray   *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString  *documentsDirectory = [paths objectAtIndex:0];
    NSString  *filePath = [NSString stringWithFormat:@"%@/%@", documentsDirectory, fileName];
    [data writeToFile:filePath atomically:YES];
}

-(NSData *) getContentOfTheFile: (NSString *) fileName
{
    if(![self fileExists:fileName]) {
        return nil;
    }
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSArray   *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString  *documentsDirectory = [paths objectAtIndex:0];
    NSString  *filePath = [NSString stringWithFormat:@"%@/%@", documentsDirectory, fileName];
    NSData *urlData = [NSData dataWithContentsOfFile:filePath];
    return urlData;
}

-(BOOL) fileExists: (NSString *) fileName
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSArray   *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString  *documentsDirectory = [paths objectAtIndex:0];
    NSString  *filePath = [NSString stringWithFormat:@"%@/%@", documentsDirectory, fileName];
    return [fileManager fileExistsAtPath:filePath];
}


-(BOOL) canHandleRequest: (NSString *) fileName
{
    return ![fileName isEqualToString:@""];
}


-(NSString *) getFileNameFromPath: (NSString *) path
{
    
    NSLog(path);
    
    if([path isEqualToString:@"s"]){
        return @"index.html";
    }
    else if ([path isEqualToString:@"app.css"]) {
          return @"app.css";
    }
    else if ([path isEqualToString:@"fonts.css"]) {
          return @"fonts.css";
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



@end
