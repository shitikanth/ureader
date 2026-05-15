#import "BridgeMessageHandler.h"
#import "EpubWindowController.h"

@implementation BridgeMessageHandler {
    __weak EpubWindowController* _controller;
}

- (instancetype)initWithController:(EpubWindowController*)controller {
    self = [super init];
    _controller = controller;
    return self;
}

- (void)userContentController:(WKUserContentController*)controller
      didReceiveScriptMessage:(WKScriptMessage*)message {
    NSDictionary* body = message.body;
    NSString* action = body[@"action"];

    if ([action isEqualToString:@"ready"]) {
        [_controller shellReady];
    } else if ([action isEqualToString:@"tocSelectionChanged"]) {
        [_controller setActiveTocIndex:[body[@"tocEntryIndex"] integerValue]];
    } else if ([action isEqualToString:@"nextChapter"]) {
        [_controller nextChapter:nil];
    } else if ([action isEqualToString:@"prevChapter"]) {
        [_controller prevChapter:nil];
    }
}

@end
