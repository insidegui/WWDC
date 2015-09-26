//
//  GRMaskImageView.m
//  ViewUtils
//
//  Created by Guilherme Rambo on 26/09/15.
//  Copyright © 2015 Guilherme Rambo. All rights reserved.
//

#import "GRMaskImageView.h"

#import "NSImage+CGImage.h"

@implementation GRMaskImageView
{
    NSColor *_tintColor;
    NSColor *_backgroundColor;
}

- (NSColor *)tintColor
{
    if (!_tintColor) return [NSColor blackColor];
    
    return _tintColor;
}

- (void)setTintColor:(NSColor *)tintColor
{
    [self willChangeValueForKey:@"tintColor"];
    _tintColor = [tintColor copy];
    [self didChangeValueForKey:@"tintColor"];
    [self setNeedsDisplay:YES];
}

- (void)setBackgroundColor:(NSColor *)backgroundColor
{
    [self willChangeValueForKey:@"backgroundColor"];
    _backgroundColor = [backgroundColor copy];
    [self didChangeValueForKey:@"backgroundColor"];
    [self setNeedsDisplay:YES];
}

- (void)setImage:(NSImage *)image
{
    [self willChangeValueForKey:@"image"];
    _image = image;
    [self didChangeValueForKey:@"image"];
    [self setNeedsDisplay:YES];
}

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    
    if (!self.image) return;
    
    CGContextRef ctx = [NSGraphicsContext currentContext].CGContext;
    CGContextSaveGState(ctx);
    
    if (self.backgroundColor) {
        CGContextSetFillColorWithColor(ctx, self.backgroundColor.CGColor);
        CGContextFillRect(ctx, self.bounds);
    }
    
    CGContextClipToMask(ctx, self.bounds, self.image.CGImage);
    CGContextSetFillColorWithColor(ctx, self.tintColor.CGColor);
    CGContextFillRect(ctx, self.bounds);
    
    CGContextRestoreGState(ctx);
}

@end
