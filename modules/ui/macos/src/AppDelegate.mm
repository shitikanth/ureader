#import "AppDelegate.h"
#import "EpubWindowController.h"

@implementation AppDelegate {
    BOOL _receivedFile;
    NSMutableDictionary<NSString*, EpubWindowController*>* _openControllers;
}

- (instancetype)init {
    self = [super init];
    _openControllers = [NSMutableDictionary dictionary];
    return self;
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
    NSString* key = [path stringByStandardizingPath];
    EpubWindowController* existing = _openControllers[key];
    if (existing) {
        [existing showWindow];
        return;
    }
    @try {
        EpubWindowController* wc = [[EpubWindowController alloc] initWithPath:path];
        _openControllers[key] = wc;
        [[NSNotificationCenter defaultCenter]
            addObserverForName:NSWindowWillCloseNotification
                        object:wc.window
                         queue:nil
                    usingBlock:^(NSNotification*) {
                        [self->_openControllers removeObjectForKey:key];
                    }];
        [wc showWindow];
    } @catch (NSException* ex) {
        NSAlert* alert = [[NSAlert alloc] init];
        alert.messageText = @"Could not open epub";
        alert.informativeText = ex.reason ?: path;
        [alert runModal];
    }
}

@end
