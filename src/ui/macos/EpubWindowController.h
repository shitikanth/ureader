#pragma once
#import <AppKit/AppKit.h>
#import <WebKit/WebKit.h>
#include <memory>
#include "EpubBook.h"

@interface EpubWindowController : NSObject <NSWindowDelegate>
- (instancetype)initWithPath:(NSString*)path;
- (void)showWindow;

// Called by BridgeMessageHandler
- (void)shellReady;
- (void)navigate:(NSString*)direction;
- (void)jumpToTocEntryIndex:(NSInteger)entryIndex;
@end
