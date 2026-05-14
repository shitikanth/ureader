#import "AppDelegate.h"
#import "EpubWindowController.h"

@implementation AppDelegate {
    BOOL _receivedFile;
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication*)app {
    return YES;
}

// Fired BEFORE applicationDidFinishLaunching: when opened via Finder
- (BOOL)application:(NSApplication*)app openFile:(NSString*)filename {
    _receivedFile = YES;
    [self openEpubAtPath:filename];
    return YES;
}

// Fired for multi-select opens from Finder
- (void)application:(NSApplication*)app openFiles:(NSArray<NSString*>*)filenames {
    _receivedFile = YES;
    for (NSString* path in filenames) [self openEpubAtPath:path];
}

- (void)applicationDidFinishLaunching:(NSNotification*)n {
    // Handle CLI: ./ureader.app/Contents/MacOS/ureader /path/to/book.epub
    NSArray<NSString*>* args = NSProcessInfo.processInfo.arguments;
    if (args.count > 1 && !_receivedFile && ![args[1] hasPrefix:@"-"]) {
        _receivedFile = YES;
        [self openEpubAtPath:args[1]];
    }
    if (!_receivedFile) {
        [NSApp terminate:nil];
    }
}

- (void)openEpubAtPath:(NSString*)path {
    @try {
        EpubWindowController* wc = [[EpubWindowController alloc] initWithPath:path];
        [wc showWindow];
        (void)wc;
    } @catch (NSException* ex) {
        NSAlert* alert = [[NSAlert alloc] init];
        alert.messageText = @"Could not open epub";
        alert.informativeText = ex.reason ?: path;
        [alert runModal];
    }
}

@end
