//
//  NSColor+CSS.m
//  ASCIIwwdc
//
//  Created by Guilherme Rambo on 07/05/15.
//  Copyright (c) 2015 Guilherme Rambo. All rights reserved.
//

#import "NSColor+CSS.h"

#define kHexColorFormat @"%02x%02x%02x"

@implementation NSColor (CSS)

- (NSString *)cssColor
{
    CGColorRef cgColor = self.CGColor;
    size_t componentCount = CGColorGetNumberOfComponents(cgColor);
    const CGFloat *components = CGColorGetComponents(cgColor);
    NSString *format = kHexColorFormat;

    if (componentCount == 2) {
        NSUInteger white = (NSUInteger)(components[0] * (CGFloat)255);
        
        return [NSString stringWithFormat:format, white, white, white];
    } else if (componentCount == 4) {
        NSUInteger R = (NSUInteger)(components[0] * (CGFloat)255);
        NSUInteger G = (NSUInteger)(components[1] * (CGFloat)255);
        NSUInteger B = (NSUInteger)(components[2] * (CGFloat)255);
        
        return [NSString stringWithFormat:format, R, G, B];
    } else {
        return @"000000";
    }
}

@end
