//
//  ProxyServer.h
//  Wrapper
//
//  Created by Stephen Ayers on 8/25/17.
//  Copyright © 2017 Stephen Ayers. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "GCDWebServers/GCDWebServers.h"

@interface ProxyServer : NSObject

@property (strong, atomic) GCDWebServer *webServer;
@property (strong, atomic) NSString *baseURL;
@property (strong, atomic, readonly) NSURL *serverURL;
@property (strong, atomic) NSURL *originalRequest;

@property (strong, atomic) NSDate *startTime;

@property (strong, atomic) NSDate *endTime;

@property (strong, atomic) NSMutableArray *requestQueue;


- (NSURL *)startProxy;

@end
