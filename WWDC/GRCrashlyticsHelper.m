//
//  GRCrashlyticsHelper.m
//  WWDC
//
//  Created by Guilherme Rambo on 29/04/15.
//  Copyright (c) 2015 Guilherme Rambo. All rights reserved.
//

#import "GRCrashlyticsHelper.h"

@import Crashlytics;

#define kCrashlyticsKey @"69b44b9b0e1f177a7fb1b6199e9a040897e9dfc0"

@implementation GRCrashlyticsHelper

+ (void)install
{
    id crashlyticsClass = NSClassFromString(@"Crashlytics");
    if (!crashlyticsClass) return;
    
    [Crashlytics startWithAPIKey:kCrashlyticsKey];
}

@end
