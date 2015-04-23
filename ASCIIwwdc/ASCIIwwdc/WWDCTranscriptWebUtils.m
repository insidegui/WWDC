//
//  WWDCTranscriptWebUtils.m
//  ASCIIwwdc
//
//  Created by Guilherme Rambo on 23/04/15.
//  Copyright (c) 2015 Guilherme Rambo. All rights reserved.
//

#import "WWDCTranscriptWebUtils.h"

@implementation WWDCTranscriptWebUtils

+ (NSURL *)htmlURL {
    return [[NSBundle bundleForClass:[self class]] URLForResource:@"transcript" withExtension:@"html"];
}

+ (NSURL *)baseURL {
    return [NSURL fileURLWithPath:[[self htmlURL].path stringByDeletingLastPathComponent]];
}

@end
