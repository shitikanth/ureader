#pragma once
#import <AppKit/AppKit.h>
#import <WebKit/WebKit.h>
#include <memory>
#include "EpubBook.h"

@interface EpubWindowController : NSObject <NSWindowDelegate>
@property (nonatomic, readonly) NSWindow* window;
- (instancetype)initWithPath:(NSString*)path;
- (void)showWindow;

// Called by BridgeMessageHandler
- (void)shellReady;
- (void)setActiveTocIndex:(NSInteger)idx;
// Called by TocSidebarViewController
- (void)jumpToTocEntryIndex:(NSInteger)entryIndex;
@end
