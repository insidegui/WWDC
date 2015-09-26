//
//  NSColor+GRProKitHelpers.m
//  GRProKit
//
//  Created by Guilherme Rambo on 22/09/15.
//  Copyright © 2015 Guilherme Rambo. All rights reserved.
//

#import "NSColor+GRProKitHelpers.h"

#define kDefaultBrightnessAdjustmentFactor 0.2

@implementation NSColor (GRProKitHelpers)

- (NSColor *)colorByAdjustingBrightnessWithFactor:(CGFloat)factor
{
    if (self.numberOfComponents == 2) {
        CGFloat white = self.whiteComponent;
        white += factor;
        
        CGFloat components[2] = { white, self.alphaComponent };
        
        return [NSColor colorWithColorSpace:self.colorSpace components:components count:2];
    }
    
    if (self.numberOfComponents == 4) {
        CGFloat red = self.redComponent;
        CGFloat green = self.greenComponent;
        CGFloat blue = self.blueComponent;
        CGFloat alpha = self.alphaComponent;
        
        CGFloat components[4] = { red+factor, green+factor, blue+factor, alpha };
        
        return [NSColor colorWithColorSpace:self.colorSpace components:components count:4];
    }
    
    return self;
}

- (NSColor *)darkerColor
{
    return [self colorByAdjustingBrightnessWithFactor:-kDefaultBrightnessAdjustmentFactor];
}

- (NSColor *)lighterColor
{
    return [self colorByAdjustingBrightnessWithFactor:kDefaultBrightnessAdjustmentFactor];
}

@end
