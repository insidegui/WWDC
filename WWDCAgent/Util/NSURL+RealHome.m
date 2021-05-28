//
//  NSURL+RealHome.m
//  WWDCAgent
//
//  Created by Guilherme Rambo on 15/07/20.
//  Copyright © 2020 Guilherme Rambo. All rights reserved.
//

#import "NSURL+RealHome.h"

@import Darwin.POSIX.pwd;

@implementation NSURL (RealHome)

+ (NSURL *)realHomeDirectoryURL
{
    static dispatch_once_t onceToken;
    static NSURL *_home;

    dispatch_once(&onceToken, ^{
        struct passwd *pwuid = getpwuid(getuid());

        if (!pwuid) {
            _home = [NSURL fileURLWithPath:NSHomeDirectory()];
        }

        _home = [NSURL fileURLWithFileSystemRepresentation:pwuid->pw_dir isDirectory:YES relativeToURL:nil];
    });

    return _home;
}

@end
