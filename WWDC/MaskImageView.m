//
//  MaskImageView.m
//  WWDC
//
//  Created by Guilherme Rambo on 26/09/15.
//  Copyright © 2015 Guilherme Rambo. All rights reserved.
//

#import "MaskImageView.h"
#import "NSImage+CGImage.h"

#import <objc/runtime.h>

static void *MaskImageImageKey = &MaskImageImageKey;

@interface MaskImageView ()

@property (nonatomic, readonly) NSImage *maskImage;

@end

@implementation MaskImageView
{
    NSColor *_tintColor;
    NSColor *_backgroundColor;
    NSImage *_image;
}

@dynamic image;

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
    objc_setAssociatedObject(self, MaskImageImageKey, image, OBJC_ASSOCIATION_COPY_NONATOMIC);
    [self didChangeValueForKey:@"image"];
    [self setNeedsDisplay:YES];
}

- (NSImage *)maskImage
{
    return objc_getAssociatedObject(self, MaskImageImageKey);
}

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    
    if (!self.maskImage) return;
    
    CGContextRef ctx = [NSGraphicsContext currentContext].CGContext;
    CGContextSaveGState(ctx);
    
    if (self.backgroundColor) {
        CGContextSetFillColorWithColor(ctx, self.backgroundColor.CGColor);
        CGContextFillRect(ctx, self.bounds);
    }

    NSSize imageSize = self.maskImage.size;
    int newWidth, newHeight = 0;
    double rw = imageSize.width / NSWidth(self.bounds);
    double rh = imageSize.height / NSHeight(self.bounds);
    
    if (rw > rh)
    {
        newHeight = round(imageSize.height / rw);
        newWidth = NSWidth(self.bounds);
    }
    else
    {
        newWidth = round(imageSize.width / rh);
        newHeight = NSHeight(self.bounds);
    }
    
    NSRect maskRect = NSMakeRect(round(NSWidth(self.bounds)/2.0 - newWidth/2.0), round(NSHeight(self.bounds)/2.0 - newHeight/2.0), newWidth, newHeight);
    
    CGContextClipToMask(ctx, maskRect, self.maskImage.CGImage);
    CGContextSetFillColorWithColor(ctx, self.tintColor.CGColor);
    CGContextFillRect(ctx, self.bounds);
    
    CGContextRestoreGState(ctx);
}

- (NSSize)intrinsicContentSize
{
    return self.maskImage.size;
}

@end
