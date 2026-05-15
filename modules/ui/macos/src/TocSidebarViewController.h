// src/ui/macos/TocSidebarViewController.h
#pragma once
#import <AppKit/AppKit.h>
#include <vector>
#include "EpubBook.h"

@class EpubWindowController;

@interface TocSidebarViewController : NSViewController <NSTableViewDataSource, NSTableViewDelegate>
- (instancetype)initWithToc:(const std::vector<TocEntry>*)toc
                 controller:(EpubWindowController*)controller;
- (void)setActiveTocIndex:(NSInteger)idx;
@end
