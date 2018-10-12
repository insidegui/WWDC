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
#pragma mark Prevent simulatenously running old version

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

#pragma mark Restore old preferences

    NSString *libraryDirPath = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES).firstObject;
    NSString *oldPrefsPath = [libraryDirPath stringByAppendingPathComponent:@"Preferences/br.com.guilhermerambo.WWDC.plist"];

    if ([[NSFileManager defaultManager] fileExistsAtPath:oldPrefsPath]) {
        NSString *newPrefsPath = [libraryDirPath stringByAppendingPathComponent:@"Preferences/io.wwdc.app.plist"];
        if (![[NSFileManager defaultManager] fileExistsAtPath:newPrefsPath]) {
            NSError *prefsCopyError;
            if (![[NSFileManager defaultManager] copyItemAtPath:oldPrefsPath toPath:newPrefsPath error:&prefsCopyError]) {
                NSAlert *alert = [NSAlert new];
                alert.messageText = @"Error copying app preferences";
                alert.informativeText = [NSString stringWithFormat:@"I tried to copy the old version's preferences but this wasn't possible. The following error occurred:\n%@\n\nDo you want to continue?", prefsCopyError.localizedDescription];
                [alert addButtonWithTitle:@"Yes"];
                [alert addButtonWithTitle:@"No"];
                if ([alert runModal] == 1001) exit(3);
            }
        }
    }

#pragma mark Restore old app support files

    NSString *appSupportPath = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES).firstObject;
    NSString *oldAppSupportPath = [appSupportPath stringByAppendingPathComponent:@"br.com.guilhermerambo.WWDC"];

    // no old version's files exist
    if (![[NSFileManager defaultManager] fileExistsAtPath:oldAppSupportPath]) return;

    NSString *newAppSupportPath = [appSupportPath stringByAppendingPathComponent:@"io.wwdc.app"];

    // new folder already exists
    if ([[NSFileManager defaultManager] fileExistsAtPath:newAppSupportPath]) return;

    NSError *supportMoveError;
    if (![[NSFileManager defaultManager] moveItemAtPath:oldAppSupportPath toPath:newAppSupportPath error:&supportMoveError]) {
        NSAlert *alert = [NSAlert new];
        alert.messageText = @"Error moving application suport directory";
        alert.informativeText = [NSString stringWithFormat:@"I tried to move the old version's app support directory but this wasn't possible. The following error occurred:\n%@\n\nDo you want to continue?", supportMoveError.localizedDescription];
        [alert addButtonWithTitle:@"Yes"];
        [alert addButtonWithTitle:@"No"];
        if ([alert runModal] == 1001) exit(2);
    }
}

@end
