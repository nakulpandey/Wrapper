//
//  ViewController.h
//  Wrapper
//
//  Created by Stephen Ayers on 8/24/17.
//  Copyright © 2017 Stephen Ayers. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
#import "ProxyServer.h"
@import QuickLook;

@interface ViewController : UIViewController <WKNavigationDelegate, WKUIDelegate, WKHTTPCookieStoreObserver, QLPreviewControllerDelegate, QLPreviewControllerDataSource>
@property (strong, atomic) WKWebView *webView;
@property (strong, atomic) WKHTTPCookieStore *cookieStore;
@property (strong, atomic) NSString *sid;
@property (strong, atomic) NSString *url;
@property (strong, atomic) ProxyServer *proxyServer;
@property (strong, atomic) NSURL *fileURL;


@property (strong, atomic) NSDate *startTime;

@property (strong, atomic) NSDate *endTime;

@end

