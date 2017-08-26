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

@interface ViewController : UIViewController <WKNavigationDelegate, WKUIDelegate, WKHTTPCookieStoreObserver>
@property (strong, atomic) WKWebView *webView;
@property (strong, atomic) WKHTTPCookieStore *cookieStore;
@property (strong, atomic) NSString *sid;
@property (strong, atomic) NSString *url;
@property (strong, atomic) ProxyServer *proxyServer;
@end

