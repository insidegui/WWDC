//
//  TBProphylaxis.m
//  WWDC
//
//  Created by Guilherme Rambo on 14/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

#import "TBProphylaxis.h"

@import Cocoa;

@implementation TBProphylaxis

+ (void)load
{
    NSArray <NSRunningApplication *> *apps = [NSRunningApplication runningApplicationsWithBundleIdentifier:@"br.com.guilhermerambo.WWDC"];
    
    BOOL shouldQuit = NO;
    
    for (NSRunningApplication *app in apps) {
        NSBundle *bundle = [NSBundle bundleWithURL:app.bundleURL];
        NSString *shortVersion = bundle.infoDictionary[@"CFBundleShortVersionString"];
        double shortVersionNumber = [shortVersion doubleValue];
        
        if (shortVersionNumber < 5) {
            if (![app forceTerminate]) {
                shouldQuit = YES;
            }
        }
    }
    
    if (shouldQuit) {
        NSAlert *alert = [NSAlert new];
        alert.messageText = @"Older version running";
        alert.informativeText = @"There's an older version of WWDC for macOS running. Version 5 can't work with older versions. Please quit the other version and launch Version 5 again.";
        [alert addButtonWithTitle:@"OK"];
        [alert runModal];
        exit(1);
    }
}

@end
