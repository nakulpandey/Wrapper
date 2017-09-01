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

        // Add a handler to respond to GET requests on any URL
        [self.webServer addDefaultHandlerForMethod:@"GET" requestClass:[GCDWebServerRequest class] asyncProcessBlock:^(__kindof GCDWebServerRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            [strongSelf handleRequest:request completion:completionBlock];
        }];
        
        [self.webServer addDefaultHandlerForMethod:@"POST" requestClass:[GCDWebServerRequest class] asyncProcessBlock:^(__kindof GCDWebServerRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            [strongSelf handleRequest:request completion:completionBlock];
        }];
        
    }
    return self;
}

- (void)handleRequest:(__kindof GCDWebServerRequest * _Nonnull)request completion:(GCDWebServerCompletionBlock  _Nonnull)completionBlock {

    NSString *urlString = [self.baseURL stringByAppendingFormat:@"%@", request.path];
    NSMutableURLRequest *newRequest = [NSMutableURLRequest new];
    newRequest.URL = [NSURL URLWithString:urlString];

    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:newRequest completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        NSHTTPURLResponse *urlResponse = (NSHTTPURLResponse*)response;
        if ([response isKindOfClass:[NSHTTPURLResponse class]])
            completionBlock([GCDWebServerDataResponse responseWithData:data contentType:urlResponse.MIMEType]);
        else
        {
        NSLog(@"Didn't get a correct URL response for some reason");
        completionBlock([GCDWebServerDataResponse responseWithData:data contentType:urlResponse.MIMEType]);
        }
    }];

    [task resume];
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
