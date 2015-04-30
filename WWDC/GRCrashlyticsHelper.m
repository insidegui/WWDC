//
//  GRCrashlyticsHelper.m
//  WWDC
//
//  Created by Guilherme Rambo on 29/04/15.
//  Copyright (c) 2015 Guilherme Rambo. All rights reserved.
//

#import "GRCrashlyticsHelper.h"

@import Crashlytics;

#define kCredentialsClassName @"GRCrashlyticsCredentials"

@implementation GRCrashlyticsHelper

+ (void)install
{
    #ifndef DEBUG
    [Crashlytics startWithAPIKey:[self apiKey] afterDelay:1.0f];
    #endif
}

+ (NSString *)apiKey
{
    Class credentialsClass = NSClassFromString(kCredentialsClassName);
    id instance = [[credentialsClass alloc] init];
    if ([instance respondsToSelector:@selector(apiKey)]) {
        return [instance apiKey];
    } else {
        return @"";
    }
}

@end
