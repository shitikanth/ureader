// src/ui/macos/TocSidebarViewController.mm
#import "TocSidebarViewController.h"
#import "EpubWindowController.h"

static NSString* const kCellID = @"TocCell";

@implementation TocSidebarViewController {
    const std::vector<TocEntry>* _toc;
    __weak EpubWindowController* _controller;
    NSTableView* _tableView;
    BOOL _settingActive;
}

- (instancetype)initWithToc:(const std::vector<TocEntry>*)toc
                 controller:(EpubWindowController*)controller {
    self = [super initWithNibName:nil bundle:nil];
    if (!self) return nil;
    _toc = toc;
    _controller = controller;
    return self;
}

- (void)loadView {
    NSScrollView* scroll = [[NSScrollView alloc] init];
    scroll.hasVerticalScroller = YES;
    scroll.autohidesScrollers = YES;
    scroll.borderType = NSNoBorder;
    scroll.drawsBackground = NO;
    scroll.automaticallyAdjustsContentInsets = YES;

    _tableView = [[NSTableView alloc] init];
    _tableView.style = NSTableViewStyleSourceList;
    _tableView.headerView = nil;
    _tableView.rowHeight = 28;
    _tableView.allowsEmptySelection = YES;
    _tableView.backgroundColor = NSColor.clearColor;
    _tableView.dataSource = self;
    _tableView.delegate = self;
    _tableView.accessibilityIdentifier = @"TocTable";

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
    if (!_toc || row < 0 || row >= (NSInteger)_toc->size()) return nil;
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
    BOOL isTopLevel = (entry.depth == 0);
    cell.textField.stringValue = [NSString stringWithUTF8String:entry.title.c_str()];
    cell.textField.font = isTopLevel
        ? [NSFont systemFontOfSize:13 weight:NSFontWeightMedium]
        : [NSFont systemFontOfSize:12 weight:NSFontWeightRegular];
    cell.textField.textColor = isTopLevel
        ? NSColor.labelColor
        : NSColor.secondaryLabelColor;

    // Remove any old leading constraint and add one with correct indent
    for (NSLayoutConstraint* c in cell.constraints) {
        if (c.firstItem == cell.textField && c.firstAttribute == NSLayoutAttributeLeading) {
            [cell removeConstraint:c];
            break;
        }
    }
    CGFloat indent = 8.0 + entry.depth * 14.0;
    [NSLayoutConstraint activateConstraints:@[
        [cell.textField.leadingAnchor constraintEqualToAnchor:cell.leadingAnchor
                                                     constant:indent]
    ]];

    return cell;
}

- (void)tableViewSelectionDidChange:(NSNotification*)note {
    if (_settingActive) return;
    NSInteger row = _tableView.selectedRow;
    if (row >= 0) [_controller jumpToTocEntryIndex:row];
}

// MARK: - Active tracking

- (void)setActiveTocIndex:(NSInteger)idx {
    _settingActive = YES;
    if (idx < 0) {
        [_tableView deselectAll:nil];
    } else {
        [_tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:(NSUInteger)idx]
                byExtendingSelection:NO];
        [_tableView scrollRowToVisible:idx];
    }
    _settingActive = NO;
}

@end
