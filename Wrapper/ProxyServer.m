//
//  ProxyServer.m
//  Wrapper
//
//  Created by Stephen Ayers on 8/25/17.
//  Copyright © 2017 Stephen Ayers. All rights reserved.
//

#import "ProxyServer.h"

@implementation ProxyServer

- (NSURL *)startProxy
{
    self.webServer = [[GCDWebServer alloc] init];
    
    // Add a handler to respond to GET requests on any URL
    [self.webServer addDefaultHandlerForMethod:@"GET"
                              requestClass:[GCDWebServerRequest class]
                              processBlock:^GCDWebServerResponse *(GCDWebServerRequest* request) {
                                  NSLog(@"request: %@ - %@", request.path, [request.URL absoluteString]);
                                  NSString *urlString = [self.baseURL stringByAppendingFormat:@"%@", request.path];
                                  return [GCDWebServerDataResponse responseWithRedirect:[NSURL URLWithString:urlString] permanent:YES];
                                 // return [GCDWebServerDataResponse responseWithHTML:@"<html><body><p>Hello World</p></body></html>"];
                                  
                              }];
    
    // Start server on port 8080
    [self.webServer startWithPort:8080 bonjourName:nil];
    NSLog(@"Visit %@ in your web browser", self.webServer.serverURL);
    
    return (self.webServer.serverURL);
}

@end
