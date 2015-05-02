//
//  UDRelease.h
//  Updater
//
//  Created by Guilherme Rambo on 01/05/15.
//  Copyright (c) 2015 Guilherme Rambo. All rights reserved.
//

@import Cocoa;

@interface UDRelease : NSObject

@property (assign) int identifier;

@property (copy) NSString *version;
@property (copy) NSString *notes;
@property (copy) NSString *download;

@property (readonly) NSURL *downloadURL;

@property (readonly) int majorVersion;
@property (readonly) int minorVersion;
@property (readonly) int patchVersion;

@property (assign) BOOL prerelease;
@property (assign) BOOL draft;

+ (UDRelease *)releaseWithDictionaryRepresentation:(NSDictionary *)dict;

@end

@interface NSApplication (UDRelease)

@property (readonly) UDRelease *ud_currentRelease;

@end