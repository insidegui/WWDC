//
//  GRReadingWindow.m
//  ViewUtils
//
//  Created by Guilherme Rambo on 20/04/15.
//  Copyright (c) 2015 Guilherme Rambo. All rights reserved.
//

#import "GRReadingWindow.h"

@interface GRReadingWindowTitlebarSeparatorView : NSView

@end

@implementation GRReadingWindow
{
    GRReadingWindowTitlebarSeparatorView *_titlebarSeparator;
}

- (void)configureTitlebar
{
    self.titlebarView.material = NSVisualEffectMaterialLight;
    self.titlebarView.state = NSVisualEffectStateActive;
    _titlebarSeparator = [[GRReadingWindowTitlebarSeparatorView alloc] initWithFrame:NSMakeRect(0, 0, NSWidth(self.titlebarView.frame), 1.0)];
    _titlebarSeparator.autoresizingMask = NSViewWidthSizable|NSViewMaxYMargin;
    [self.titlebarView addSubview:_titlebarSeparator];
    _titlebarSeparator.hidden = self.titlebarAppearsTransparent;
}

- (void)setTitlebarAppearsTransparent:(BOOL)titlebarAppearsTransparent
{
    [super setTitlebarAppearsTransparent:titlebarAppearsTransparent];
    _titlebarSeparator.hidden = titlebarAppearsTransparent;
}

@end

@implementation GRReadingWindowTitlebarSeparatorView

- (void)drawRect:(NSRect)dirtyRect
{
    [[NSColor colorWithCalibratedWhite:0.5 alpha:0.5] setFill];
    NSRectFillUsingOperation(dirtyRect, NSCompositePlusDarker);
}

- (BOOL)allowsVibrancy
{
    return YES;
}

@end