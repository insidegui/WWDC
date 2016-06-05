//
//  UDRelease.m
//  Updater
//
//  Created by Guilherme Rambo on 01/05/15.
//  Copyright (c) 2015 Guilherme Rambo. All rights reserved.
//

#import "UDRelease.h"

@implementation UDRelease

+ (UDRelease *)releaseWithDictionaryRepresentation:(NSDictionary *)dict
{
    UDRelease *release = [[UDRelease alloc] init];
    
    release.identifier = [dict[@"id"] intValue];
    release.version = dict[@"tag_name"];
    release.notes = dict[@"body"];
    
    if ([dict[@"assets"] respondsToSelector:@selector(count)]) {
        if ([dict[@"assets"] count] > 0) {
            release.download = dict[@"assets"][0][@"browser_download_url"];
        }
    }
    
    release.prerelease = [dict[@"prerelease"] boolValue];
    release.draft = [dict[@"draft"] boolValue];
    
    return release;
}

- (NSURL *)downloadURL
{
    return [NSURL URLWithString:self.download];
}

- (int)majorVersion
{
    NSArray *components = [self.version componentsSeparatedByString:@"."];
    
    return [components[0] intValue];
}

- (int)minorVersion
{
    NSArray *components = [self.version componentsSeparatedByString:@"."];
    
    if (components.count > 1) {
        return [components[1] intValue];
    } else {
        return 0;
    }
}

- (int)patchVersion
{
    NSArray *components = [self.version componentsSeparatedByString:@"."];
    
    if (components.count > 2) {
        return [components[2] intValue];
    } else {
        return 0;
    }
}

- (BOOL)isGreaterThan:(id)object
{
    UDRelease *otherRelease = object;
    
    if (self.majorVersion > otherRelease.majorVersion) {
        return YES;
    }
    
    if (self.majorVersion == otherRelease.majorVersion) {
        if (self.minorVersion == otherRelease.minorVersion) {
            if (self.patchVersion > otherRelease.patchVersion) {
                return YES;
            } else {
                return NO;
            }
        } else {
            if (self.minorVersion > otherRelease.minorVersion) {
                return YES;
            }
        }
    }
    
    return NO;
}

@end


@implementation NSApplication (UDRelease)

- (UDRelease *)ud_currentRelease
{
    UDRelease *release = [[UDRelease alloc] init];
    
    release.version = [NSBundle mainBundle].infoDictionary[@"CFBundleShortVersionString"];
    
    return release;
}

@end