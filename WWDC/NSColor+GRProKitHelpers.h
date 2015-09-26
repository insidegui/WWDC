//
//  NSColor+GRProKitHelpers.h
//  GRProKit
//
//  Created by Guilherme Rambo on 22/09/15.
//  Copyright © 2015 Guilherme Rambo. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface NSColor (GRProKitHelpers)

- (NSColor *__nonnull)colorByAdjustingBrightnessWithFactor:(CGFloat)factor;

@property (nonatomic, readonly) NSColor *__nonnull darkerColor;
@property (nonatomic, readonly) NSColor *__nonnull lighterColor;

@end
