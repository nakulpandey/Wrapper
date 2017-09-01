//
//  ViewController.m
//  Wrapper
//
//  Created by Stephen Ayers on 8/24/17.
//  Copyright © 2017 Stephen Ayers. All rights reserved.
//

// TODO:
// Add Proxy Server
// Spinner
// Handle Files
// Navigation
// Logout
// Encrypt
// Error messages
// Make stand alone SDK + App
// Capture logins

#import "ViewController.h"
@import QuickLook;

static NSString *const SID_COOKIE = @"sid";
static BOOL UseProxy = NO;
static NSString *DefaultURL = @"https://community.ausure.com.au";

// @"https://coffeetest-15c5fb901dc.force.com"; // @"https://www.salesforce.com";
// @"https://community.ausure.com.au";

@interface ViewController ()

@end

@implementation ViewController

- (NSString *)cookieKey
{
    return @"MySavedCookies"; // TODO: Make unique with buldle & hostname name
}

- (void)debugCookieStore
{
    [self.cookieStore getAllCookies:^(NSArray *cookies) {
        for (NSHTTPCookie *cookie in cookies)
        {
            NSLog(@"name: '%@' value: '%@' domain: '%@' path: '%@'",   [cookie name], [cookie value], [cookie domain], [cookie path]);
            if ([[[cookie name] lowercaseString] isEqualToString:SID_COOKIE])
            {
                NSLog(@"sid = %@", [cookie value]);
            }
        }
    } ];
}

- (void)setupDefaultCookies
{
    if (!self.cookieStore)
        self.cookieStore = self.webView.configuration.websiteDataStore.httpCookieStore;
    
    // Fetch prior Cookies - TODO: Only handle SID
    // TODO: Encrypt data - https://github.com/nielsmouthaan/SecureNSUserDefaults
    
    NSData *cookiesdata = [[NSUserDefaults standardUserDefaults] objectForKey:self.cookieKey];
    if (cookiesdata && [cookiesdata length]) {
        NSArray *cookies = [NSKeyedUnarchiver unarchiveObjectWithData:cookiesdata];
        
        for (NSHTTPCookie *cookie in cookies) {
            if ([[[cookie name] lowercaseString] isEqualToString:[SID_COOKIE lowercaseString]])
                self.sid = [[cookie value] lowercaseString];
            [self.cookieStore setCookie:cookie completionHandler:nil];
        }
    }
    [self.cookieStore addObserver:self];
}

- (void)spinner:(BOOL)start
{
    // self.spinner.hidden = !start;
}

- (NSURLRequest *)URLRequest
{
    NSURL *url = [NSURL URLWithString:self.url];
    if (!url.scheme || ![url.scheme isEqualToString:@"https"])
    {
        // TODO: Log error that only https supported
        return nil;
    }
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    return request;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    if (!self.url)
    {
        // Grab default from bundle
        // self.url = [[NSBundle mainBundle] pathForResource:@"index" ofType:@"html"];
    }
    if (!self.url)
        self.url = DefaultURL;
    
    NSURLRequest *request = self.URLRequest;
    if (UseProxy)
    {
        self.proxyServer = [[ProxyServer alloc] init];
        self.proxyServer.baseURL = request.URL.absoluteString;
        request = [NSURLRequest requestWithURL:self.proxyServer.startProxy];
    }
    
    WKWebViewConfiguration *theConfiguration = [[WKWebViewConfiguration alloc] init];
    self.webView = [[WKWebView alloc] initWithFrame:self.view.frame configuration:theConfiguration];
    self.webView.UIDelegate = self;
    self.webView.navigationDelegate = self;
    self.webView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    
    // Throw up a nice progress indicator
    [self spinner:YES];
    
    // Inject cookies for Session/Refresh
    [self setupDefaultCookies];
    
    NSLog(@"Loading initial page: %@", request.URL);
    if (request)
        [self.webView loadRequest:request];
    else
    {
        // TODO: Display error for invalid URL
    }
    [self.view addSubview:self.webView];
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)webViewDidClose:(WKWebView *)webView
{
    [self spinner:NO];
    [self.webView stopLoading];
    self.webView = nil;
}

- (void)webView:(WKWebView *)webView didCommitNavigation:(WKNavigation *)navigation
{
    NSLog(@"navigating to: %@", self.webView.URL);
    
    // Start spinner
    [self spinner:YES];
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation
{
    NSLog(@"didFinishNavigation to %@", self.webView.URL);
    // Stop spinner
    [self spinner:NO];
}

- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error
{
    NSLog(@"navigation to %@ failed with Error: %@", self.webView.URL, error.description);
    
    // Stop spinner
    [self spinner:NO];
    // Throw up user notice
    
}

- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error
{
    NSLog(@"navigation to %@ failed with %@ error.", self.webView.URL, error.description);
    
    // Stop spinner
    [self spinner:NO];
    // Throw up user notice
}

- (void)webView:(WKWebView *)webView decidePolicyForNavigationResponse:(WKNavigationResponse *)navigationResponse decisionHandler:(void (^)(WKNavigationResponsePolicy))decisionHandler{
    NSHTTPURLResponse *response = (NSHTTPURLResponse *)navigationResponse.response;
    NSLog(@"decidePolicyForNavigationResponse");
    
    NSArray *cookies = [NSHTTPCookie cookiesWithResponseHeaderFields:[response allHeaderFields] forURL:response.URL];
    for (NSHTTPCookie *cookie in cookies) {
        [[NSHTTPCookieStorage sharedHTTPCookieStorage] setCookie:cookie];
    }
    
    decisionHandler(WKNavigationResponsePolicyAllow);
}

- (NSInteger)numberOfPreviewItemsInPreviewController:(QLPreviewController *)controller {
    return 1;
}
- (id<QLPreviewItem>)previewController:(QLPreviewController *)controller previewItemAtIndex:(NSInteger)index {
    return self.fileURL;
}

- (BOOL)userIsLoggedIn
{
    return YES;
}

- (BOOL)requestedURLIsNonProxySite:(NSURL *)url
{
    return [url.absoluteString containsString:self.proxyServer.baseURL] && ![url.absoluteString containsString:@"/login/"];
}

- (NSURL *)mapURLtoProxy:(NSURL *)url
{
    NSURLComponents *components = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
    NSURLComponents *proxyComponents = [NSURLComponents componentsWithURL:self.proxyServer.serverURL         resolvingAgainstBaseURL:NO];
    components.host = proxyComponents.host;
    components.port = proxyComponents.port;
    components.scheme = proxyComponents.scheme; // TODO: Determine how to use https for local traffic
    return [components URL];
}


- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    
    NSURLRequest *request = navigationAction.request;
    NSURL *requestedURL = request.URL;
    NSLog(@"Navigate URL: %@", requestedURL.absoluteString);
    
    if (self.userIsLoggedIn && UseProxy && [self requestedURLIsNonProxySite:requestedURL])
    {
        // URL points directly to site not Proxy server
        
        NSLog(@"redirecting to %@", [self mapURLtoProxy:requestedURL].absoluteString);
        //[self.webView performSelector:@selector(loadRequest:) withObject:[NSURLRequest requestWithURL:[self mapURLtoProxy:requestedURL]] afterDelay:1.0];
       [self.webView loadRequest:[NSURLRequest requestWithURL:[self mapURLtoProxy:requestedURL]]];
        if (decisionHandler)
            decisionHandler(WKNavigationActionPolicyAllow);
        return;
    }
    
    NSString *externalFileExtension = requestedURL.pathExtension;
    if ([[externalFileExtension lowercaseString] isEqualToString:@"pdf"] ||
        [requestedURL.absoluteString containsString:@"servlet.FileDownload"])
    {
        
        //Fire download -- File events are not consistent...
        
        self.fileURL = requestedURL;
        NSLog(@"externalURL is %@", self.fileURL);
        QLPreviewController *ql = [[QLPreviewController alloc] init];
        ql.title = self.fileURL.absoluteString;
        ql.delegate = self;
        ql.dataSource = self;
        
        if ([requestedURL checkResourceIsReachableAndReturnError:nil] && [QLPreviewController canPreviewItem:self.fileURL])
            [self presentViewController:ql animated:YES completion:nil];
        else
        {
            // TODO: Tell user not supported file type.  Maybe try DocInterctionHandle
            NSLog(@"Quicklook does not support file type");
        }
        
        if (decisionHandler) {
            decisionHandler(WKNavigationActionPolicyCancel);
        }
        return;
    }
    decisionHandler(WKNavigationActionPolicyAllow);
}

- (void)persistCookies
{
    // Upddate to filter only specific cookies (sid)
    [self.cookieStore getAllCookies:^(NSArray *cookies) {
        NSData *cookiesdata = [NSKeyedArchiver archivedDataWithRootObject:cookies];
        // TODO: Encrypt data
        [[NSUserDefaults standardUserDefaults] setObject:cookiesdata forKey:self.cookieKey];
    } ];
}

- (void)cookiesDidChangeInCookieStore:(WKHTTPCookieStore *)cookieStore
{
    NSLog(@"cookiesDidChangeInCookieStore");
    
    // Look for the SID
    [self.cookieStore getAllCookies:^(NSArray *cookies) {
        for (NSHTTPCookie *cookie in cookies)
        {
            // NSLog(@"name: '%@' value: '%@' domain: '%@' path: '%@'",   [cookie name], [cookie value], [cookie domain], [cookie path]);
            if ([[[cookie name] lowercaseString] isEqualToString:[SID_COOKIE lowercaseString]])
            {
                if (!self.sid || ![[cookie value] isEqualToString:self.sid] )
                {
                    NSLog(@"SID Changed!");
                    self.sid = cookie.value;
                }
            }
        }
    } ];
    
    // TODO: Only persist on relevent change
    [self persistCookies];
}

@end
