// src/ui/macos/TocSidebarViewController.mm
#import "TocSidebarViewController.h"
#import "EpubWindowController.h"

static NSString* const kCellID = @"TocCell";

@implementation TocSidebarViewController {
    const std::vector<TocEntry>* _toc;
    __weak EpubWindowController* _controller;
    NSTableView* _tableView;
}

- (instancetype)initWithToc:(const std::vector<TocEntry>*)toc
                 controller:(EpubWindowController*)controller {
    self = [super initWithNibName:nil bundle:nil];
    _toc = toc;
    _controller = controller;
    return self;
}

- (void)loadView {
    NSScrollView* scroll = [[NSScrollView alloc] init];
    scroll.hasVerticalScroller = YES;
    scroll.autohidesScrollers = YES;
    scroll.borderType = NSNoBorder;

    _tableView = [[NSTableView alloc] init];
    _tableView.style = NSTableViewStyleSourceList;
    _tableView.headerView = nil;
    _tableView.rowHeight = 24;
    _tableView.allowsEmptySelection = YES;
    _tableView.dataSource = self;
    _tableView.delegate = self;

    NSTableColumn* col = [[NSTableColumn alloc] initWithIdentifier:@"title"];
    col.resizingMask = NSTableColumnAutoresizingMask;
    [_tableView addTableColumn:col];
    [_tableView sizeLastColumnToFit];

    scroll.documentView = _tableView;
    self.view = scroll;
}

// MARK: - NSTableViewDataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView*)tv {
    return _toc ? (NSInteger)_toc->size() : 0;
}

// MARK: - NSTableViewDelegate

- (NSView*)tableView:(NSTableView*)tv
  viewForTableColumn:(NSTableColumn*)col
                 row:(NSInteger)row {
    NSTableCellView* cell = [tv makeViewWithIdentifier:kCellID owner:self];
    if (!cell) {
        cell = [[NSTableCellView alloc] init];
        cell.identifier = kCellID;
        NSTextField* tf = [NSTextField labelWithString:@""];
        tf.lineBreakMode = NSLineBreakByTruncatingTail;
        tf.translatesAutoresizingMaskIntoConstraints = NO;
        [cell addSubview:tf];
        cell.textField = tf;
        // vertical centre
        [NSLayoutConstraint activateConstraints:@[
            [tf.centerYAnchor constraintEqualToAnchor:cell.centerYAnchor],
            [tf.trailingAnchor constraintEqualToAnchor:cell.trailingAnchor constant:-4]
        ]];
        // leading constraint stored as a named tag via objc_setAssociatedObject isn't
        // available cleanly — we add it below every time since reuse resets it anyway.
    }
    const auto& entry = (*_toc)[row];
    cell.textField.stringValue = [NSString stringWithUTF8String:entry.title.c_str()];
    cell.textField.font = [NSFont systemFontOfSize:13];

    // Remove any old leading constraint and add one with correct indent
    for (NSLayoutConstraint* c in cell.constraints) {
        if (c.firstAttribute == NSLayoutAttributeLeading) {
            [cell removeConstraint:c];
            break;
        }
    }
    CGFloat indent = 12.0 + entry.depth * 16.0;
    [NSLayoutConstraint activateConstraints:@[
        [cell.textField.leadingAnchor constraintEqualToAnchor:cell.leadingAnchor
                                                     constant:indent]
    ]];

    return cell;
}

- (void)tableViewSelectionDidChange:(NSNotification*)note {
    NSInteger row = _tableView.selectedRow;
    if (row >= 0) [_controller jumpToTocEntryIndex:row];
}

// MARK: - Active tracking

- (void)setActiveTocIndex:(NSInteger)idx {
    if (idx < 0) {
        [_tableView deselectAll:nil];
        return;
    }
    [_tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:(NSUInteger)idx]
            byExtendingSelection:NO];
    [_tableView scrollRowToVisible:idx];
}

@end
