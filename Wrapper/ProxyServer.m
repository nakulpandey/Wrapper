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

@end


@implementation ProxyServer

- (instancetype)init {
    self = [super init];
    if (self) {
        NSURLSessionConfiguration *config = [NSURLSessionConfiguration ephemeralSessionConfiguration];
        self.session = [NSURLSession sessionWithConfiguration:config];

        __weak typeof(self) weakSelf = self;

        self.webServer = [[GCDWebServer alloc] init];
        
        
        [self.webServer addHandlerForMethod:@"GET" pathRegex:@"/" requestClass:[GCDWebServerRequest class]   processBlock:^GCDWebServerResponse *(GCDWebServerRequest* request) {
            NSArray       *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
            NSString  *documentsDirectory = [paths objectAtIndex:0];
            
            NSString  *filePath = [NSString stringWithFormat:@"%@/%@", documentsDirectory,@"index.html"];
            
            NSError *error;
            NSString *fileContents = [NSString stringWithContentsOfFile:filePath encoding:NSUTF8StringEncoding error:&error];
            NSLog(@"File contents: %@",fileContents);
            if (error)
                NSLog(@"Error reading file: %@", error.localizedDescription);
            GCDWebServerResponse *response = [GCDWebServerDataResponse responseWithHTML:fileContents];
            response.cacheControlMaxAge = 3600;
            return response;
        }];
        
//        [self.webServer addHandlerForMethod:@"GET" pathRegex:@"/.*\.js" requestClass:[GCDWebServerRequest class]   processBlock:^GCDWebServerResponse *(GCDWebServerRequest* request) {
//          
//            
//            NSString *stringURL = @"https://one.perf.demo.community/";
//            NSURL  *url = [NSURL URLWithString:[stringURL stringByAppendingString:[request.URL.absoluteURL.absoluteString substringFromIndex:[request.URL.baseURL.absoluteString length]]]];
//            
//            GCDWebServerResponse *response = [GCDWebServerDataResponse responseWithData:[NSData dataWithContentsOfURL:url] contentType:@"text/javascript;charset=UTF-8"];
//            return response;
//            
//        }];
        
        [self.webServer addHandlerForMethod:@"GET" pathRegex:@"/.*\.js" requestClass:[GCDWebServerRequest class]   processBlock:^GCDWebServerResponse *(GCDWebServerRequest* request) {
            
            
            NSString *stringURL = @"https://one.perf.demo.community/";
            NSURL  *url = [NSURL URLWithString:[stringURL stringByAppendingString:[request.URL.absoluteURL.absoluteString substringFromIndex:[request.URL.baseURL.absoluteString length]]]];
            
            GCDWebServerResponse *response = [GCDWebServerDataResponse responseWithData:[NSData dataWithContentsOfURL:url] contentType:@"text/javascript;charset=UTF-8"];
            return response;
            
        }];
        
        [self.webServer addHandlerForMethod:@"GET" pathRegex:@"/.*\.css" requestClass:[GCDWebServerRequest class]   processBlock:^GCDWebServerResponse *(GCDWebServerRequest* request) {
            
            
            
            NSString *stringURL = @"https://one.perf.demo.community/";
            NSURL  *url = [NSURL URLWithString:[stringURL stringByAppendingString:[request.URL.absoluteURL.absoluteString substringFromIndex:[request.URL.baseURL.absoluteString length]]]];
            
            GCDWebServerResponse *response = [GCDWebServerDataResponse responseWithData:[NSData dataWithContentsOfURL:url] contentType:@"text/css;charset=UTF-8"];
            return response;
            
        }];
        
        
        [self.webServer addHandlerForMethod:@"GET" pathRegex:@"/.*sfsites/aura.*" requestClass:[GCDWebServerRequest class]   processBlock:^GCDWebServerResponse *(GCDWebServerRequest* request) {
            
            
            
            NSString *stringURL = @"https://one.perf.demo.community/";
            NSURL  *url = [NSURL URLWithString:[stringURL stringByAppendingString:[request.URL.absoluteURL.absoluteString substringFromIndex:[request.URL.baseURL.absoluteString length]]]];
            
            GCDWebServerResponse *response = [GCDWebServerDataResponse responseWithData:[NSData dataWithContentsOfURL:url] contentType:@"application/json;charset=UTF-8"];
            return response;
            
        }];

//        // Add a handler to respond to GET requests on any URL
//        [self.webServer addDefaultHandlerForMethod:@"GET" requestClass:[GCDWebServerRequest class] asyncProcessBlock:^(__kindof GCDWebServerRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
//            __strong typeof(weakSelf) strongSelf = weakSelf;
//            [strongSelf handleRequest:request completion:completionBlock];
//        }];
        
//        [self.webServer addDefaultHandlerForMethod:@"POST" requestClass:[GCDWebServerRequest class] asyncProcessBlock:^(__kindof GCDWebServerRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
//            __strong typeof(weakSelf) strongSelf = weakSelf;
//            NSLog(@"We have received post call ");
//            [strongSelf handleRequest:request completion:completionBlock];
//        }];
        
    }
    return self;
}

- (void)handleRequest:(__kindof GCDWebServerRequest * _Nonnull)request completion:(GCDWebServerCompletionBlock  _Nonnull)completionBlock {
    
    
    
    
    
    
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

@end
