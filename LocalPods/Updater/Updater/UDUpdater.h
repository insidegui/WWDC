//
//  UDUpdater.h
//  Updater
//
//  Created by Guilherme Rambo on 01/05/15.
//  Copyright (c) 2015 Guilherme Rambo. All rights reserved.
//

@import Cocoa;

@class UDRelease;

@interface UDUpdater : NSObject

+ (UDUpdater *)sharedUpdater;

/**
 If updateAutomatically is set to YES, updates are downloaded and applied automatically
 */
@property (nonatomic, assign) BOOL updateAutomatically;

/**
 Checks for new releases, if a new release is found, "latestRelease" contains information about It.
 "callback" is executed on main thread
 */
- (void)checkForUpdatesWithCompletionHandler:(void (^)(UDRelease *latestRelease))callback;

/**
 Downloads and installs the specified release, this is only necessary if updateAutomatically is set to NO
 "callback" is executed on main thread
 */
- (void)downloadAndInstallRelease:(UDRelease *)release completionHandler:(void(^)(BOOL installed))callback;

@end
