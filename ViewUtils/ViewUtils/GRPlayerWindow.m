//
//  VXPlayerWindow.m
//  VLCX
//
//  Created by Guilherme Rambo on 15/12/14.
//  Copyright (c) 2014 Guilherme Rambo. All rights reserved.
//

#import "GRPlayerWindow.h"

@interface GRPlayerWindow ()

@property (readonly) NSVisualEffectView *titlebarView;

@end

// this is just a hack so we can access titlebarView without warnings from the compiler,
// titlebarView is actually a property of NSThemeFrame, which is a subclass of NSView ;)
@interface NSView (Titlebar)
- (NSVisualEffectView *)titlebarView;
@end

@implementation GRPlayerWindow

- (instancetype)initWithContentRect:(NSRect)contentRect styleMask:(NSUInteger)aStyle backing:(NSBackingStoreType)bufferingType defer:(BOOL)flag
{
    if (!(self = [super initWithContentRect:contentRect styleMask:aStyle backing:bufferingType defer:flag])) return nil;

    self.movableByWindowBackground = YES;
    self.styleMask |= NSFullSizeContentViewWindowMask;
    self.titlebarView.material = NSVisualEffectMaterialDark;
    self.titlebarView.state = NSVisualEffectStateActive;
    
    return self;
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