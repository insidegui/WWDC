//
//  main.m
//  WWDC
//
//  Created by Guilherme Rambo on 14/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

@import Cocoa;

#import "WWDCAppearance.h"

int main(int argc, const char **argv) {
    if ([NSRunningApplication runningApplicationsWithBundleIdentifier:@"br.com.guilhermerambo.WWDC"].count > 0) {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.alertStyle = NSAlertStyleCritical;
        alert.messageText = @"Older version running";
        alert.informativeText = @"You have an older version of WWDC for macOS running, please quit it before running this new version.";
        alert.window.appearance = [WWDCAppearance appearance];
        [alert addButtonWithTitle:@"OK"];
        [alert runModal];
        exit(1);
    }
    
    return NSApplicationMain(argc, argv);
}
