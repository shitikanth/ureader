#pragma once
#import <WebKit/WebKit.h>

@class EpubWindowController;

@interface BridgeMessageHandler : NSObject <WKScriptMessageHandler>
- (instancetype)initWithController:(EpubWindowController*)controller;
@end
