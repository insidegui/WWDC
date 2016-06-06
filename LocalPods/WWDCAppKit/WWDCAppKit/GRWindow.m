//
//  GRWindow.m
//  WWDCAppKit
//
//  Created by Guilherme Rambo on 20/04/15.
//  Copyright (c) 2015 Guilherme Rambo. All rights reserved.
//

#import "GRWindow.h"

@implementation GRWindow

- (instancetype)initWithContentRect:(NSRect)contentRect styleMask:(NSUInteger)aStyle backing:(NSBackingStoreType)bufferingType defer:(BOOL)flag
{
    if (!(self = [super initWithContentRect:contentRect styleMask:aStyle backing:bufferingType defer:flag])) return nil;
    
    self.movableByWindowBackground = YES;
    self.styleMask |= NSFullSizeContentViewWindowMask;
    
    [self configureTitlebar];
    
    return self;
}

- (void)configureTitlebar
{
    return;
}

- (void)hideTitlebarAnimated:(BOOL)animated
{
    // do not hide the titlebar when in fullscreen mode
    if ((self.styleMask & NSFullScreenWindowMask)) return;
    
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
        if (!animated) [context setDuration:0];
        
        self.titlebarView.animator.alphaValue = 0;
    } completionHandler:^{
        _titlebarVisible = NO;
        
        self.titlebarView.hidden = YES;
    }];
}

- (void)showTitlebarAnimated:(BOOL)animated
{
    self.titlebarView.hidden = NO;
    
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
        if (!animated) [context setDuration:0];
        
        self.titlebarView.animator.alphaValue = 1;
    } completionHandler:^{
        _titlebarVisible = YES;
    }];
}

- (NSVisualEffectView *)titlebarView
{
    // [self.contentView superview] is an instance of NSThemeFrame, which has a property called titlebarView
    return [[self.contentView superview] titlebarView];
}

@end
