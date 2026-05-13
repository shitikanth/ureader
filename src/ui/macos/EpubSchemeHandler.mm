#import "EpubSchemeHandler.h"

static NSString* mimeTypeForPath(NSString* path) {
    NSString* ext = path.pathExtension.lowercaseString;
    NSDictionary* map = @{
        @"html":  @"text/html; charset=utf-8",
        @"xhtml": @"text/html; charset=utf-8",
        @"css":   @"text/css",
        @"js":    @"application/javascript",
        @"png":   @"image/png",
        @"jpg":   @"image/jpeg",
        @"jpeg":  @"image/jpeg",
        @"gif":   @"image/gif",
        @"svg":   @"image/svg+xml",
        @"ttf":   @"font/ttf",
        @"otf":   @"font/otf",
        @"woff":  @"font/woff",
        @"woff2": @"font/woff2",
    };
    return map[ext] ?: @"application/octet-stream";
}

@implementation EpubSchemeHandler {
    EpubBook* _book;
}

- (instancetype)initWithBook:(EpubBook*)book {
    self = [super init];
    _book = book;
    return self;
}

- (void)webView:(WKWebView*)webView
    startURLSchemeTask:(id<WKURLSchemeTask>)task {

    // URL: epub://<host>/<zip-path> — strip leading slash to get ZIP path
    NSString* rawPath = task.request.URL.path;
    if ([rawPath hasPrefix:@"/"]) rawPath = [rawPath substringFromIndex:1];
    std::string zipPath = rawPath.UTF8String;

    auto bytes = _book->readFile(zipPath);

    if (bytes.empty()) {
        NSHTTPURLResponse* resp = [[NSHTTPURLResponse alloc]
            initWithURL:task.request.URL
             statusCode:404
            HTTPVersion:@"HTTP/1.1"
           headerFields:nil];
        [task didReceiveResponse:resp];
        [task didFinish];
        return;
    }

    NSString* mime = mimeTypeForPath(rawPath);
    NSHTTPURLResponse* resp = [[NSHTTPURLResponse alloc]
        initWithURL:task.request.URL
         statusCode:200
        HTTPVersion:@"HTTP/1.1"
       headerFields:@{@"Content-Type": mime}];
    [task didReceiveResponse:resp];
    [task didReceiveData:[NSData dataWithBytes:bytes.data() length:bytes.size()]];
    [task didFinish];
}

- (void)webView:(WKWebView*)webView
    stopURLSchemeTask:(id<WKURLSchemeTask>)task {
    // No async work to cancel
}

@end
