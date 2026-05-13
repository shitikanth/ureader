#import "AppDelegate.h"

@implementation AppDelegate

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication*)app {
    return YES;
}

- (void)applicationDidFinishLaunching:(NSNotification*)n {
    NSArray<NSString*>* args = NSProcessInfo.processInfo.arguments;
    if (args.count < 2) {
        [NSApp terminate:nil];
    }
}

@end
