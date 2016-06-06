//
//  GRBannerView.m
//  WWDCAppKit
//
//  Created by Guilherme Rambo on 09/06/15.
//  Copyright (c) 2015 Guilherme Rambo. All rights reserved.
//

#import "GRBannerView.h"

@implementation GRBannerView
{
    BOOL _gr_commonInited;
}

- (instancetype)initWithFrame:(NSRect)frameRect
{
    if (!(self = [super initWithFrame:frameRect])) return nil;
    
    [self _gr_commonInit];
    
    return self;
}

- (void)awakeFromNib
{
    [super awakeFromNib];
    [self _gr_commonInit];
}

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    
    [_backgroundColor setFill];
    NSRectFill(dirtyRect);
    
    NSRect sepRect = NSMakeRect(0, NSHeight(self.frame)-1.0, NSWidth(self.frame), 1.0);
    [_separatorColor setFill];
    NSRectFill(sepRect);
}

- (void)setBackgroundColor:(NSColor *)backgroundColor
{
    _backgroundColor = [backgroundColor copy];
    
    [self setNeedsDisplay:YES];
}

- (void)setSeparatorColor:(NSColor *)separatorColor
{
    _separatorColor = [separatorColor copy];
    
    [self setNeedsDisplay:YES];
}

#pragma mark Private API

- (void)_gr_commonInit
{
    if (_gr_commonInited) return;
    
    _gr_commonInited = YES;
    
    if (!_backgroundColor) {
        _backgroundColor = [NSColor whiteColor];
    }
    if (!_separatorColor) {
        _separatorColor = [NSColor grayColor];
    }
    
    self.wantsLayer = YES;
}

@end
