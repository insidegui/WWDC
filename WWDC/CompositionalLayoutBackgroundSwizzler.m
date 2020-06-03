//
//  CompositionalLayoutBackgroundSwizzler.m
//  WWDC
//
//  Created by Guilherme Rambo on 31/05/20.
//  Copyright © 2020 Guilherme Rambo. All rights reserved.
//

#import "CompositionalLayoutBackgroundSwizzler.h"

@import Cocoa;
@import ConfUIFoundation;

#import "WWDC-Swift.h"
#import <objc/runtime.h>

/**
 This works around an issue where NSCollectionViewCompositionalLayout draws a weird background
 color behind each section. Swizzling setBackgroundColor: on _NSScrollViewContentBackgroundView
 was the only viable workaround I could find.
 */

@implementation CompositionalLayoutBackgroundSwizzler

+ (void)load
{
    Method m = class_getInstanceMethod(NSClassFromString(@"_NSScrollViewContentBackgroundView"), NSSelectorFromString(@"setBackgroundColor:"));
    if (!m) return;

    Method m2 = class_getInstanceMethod(NSClassFromString(@"OverrideNSScrollViewBackgroundView"), NSSelectorFromString(@"setBackgroundColor:"));
    if (!m2) return;

    class_addMethod(NSClassFromString(@"_NSScrollViewContentBackgroundView"), NSSelectorFromString(@"_original_setBackgroundColor:"), method_getImplementation(m), method_getTypeEncoding(m));

    method_exchangeImplementations(m, m2);
}

@end

@interface OverrideNSScrollViewBackgroundView: NSView
@end

@implementation OverrideNSScrollViewBackgroundView

- (void)setBackgroundColor:(NSColor *)color
{
    [self _original_setBackgroundColor:[NSColor contentBackground]];
}

- (void)_original_setBackgroundColor:(NSColor *)color
{

}

@end
