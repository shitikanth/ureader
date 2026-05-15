// Helper tool: writes an XCTestConfiguration to disk so that xctest can run
// the bundle in UI-testing mode (XCUIApplication requires this).
// Usage: generate_xctest_config <bundle_path> <output_config_path>
#import <Foundation/Foundation.h>

// XCTestConfiguration is a private class; we access it by name at runtime.
int main(int argc, char *argv[]) {
    @autoreleasepool {
        if (argc != 3) {
            fprintf(stderr, "Usage: generate_xctest_config <bundle_path> <output_path>\n");
            return 1;
        }
        NSString *bundlePath = @(argv[1]);
        NSString *outputPath = @(argv[2]);

        Class configClass = NSClassFromString(@"XCTestConfiguration");
        if (!configClass) {
            fprintf(stderr, "ERROR: XCTestConfiguration class not found\n");
            return 1;
        }

        id config = [[configClass alloc] init];
        [config setValue:[NSURL fileURLWithPath:bundlePath] forKey:@"testBundleURL"];
        [config setValue:@YES forKey:@"initializeForUITesting"];
        [config setValue:@NO forKey:@"reportResultsToIDE"];

        NSError *err = nil;
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:config
                                            requiringSecureCoding:NO
                                                            error:&err];
        if (err || !data) {
            fprintf(stderr, "ERROR: archiving failed: %s\n",
                    err.localizedDescription.UTF8String ?: "unknown");
            return 1;
        }
        if (![data writeToFile:outputPath atomically:YES]) {
            fprintf(stderr, "ERROR: could not write to %s\n", outputPath.UTF8String);
            return 1;
        }
        return 0;
    }
}
