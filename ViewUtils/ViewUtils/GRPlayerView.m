//
//  GRPlayerView.m
//  ViewUtils
//
//  Created by Guilherme Rambo on 19/04/15.
//  Copyright (c) 2015 Guilherme Rambo. All rights reserved.
//

#import "GRPlayerView.h"
#import "GRPlayerWindow.h"

@interface AVPlayerView ()

- (BOOL)_mouseInNoHideArea;
- (BOOL)canHideControls;

@end

@interface GRPlayerView ()

@property (readonly) GRPlayerWindow *playerWindow;
@property (strong) NSTimer *titlebarTimer;

@end

#define kHideTitlebarTimerInterval 3.0f

@implementation GRPlayerView

- (void)setupHideTitlebarTimer
{
    [self.titlebarTimer invalidate];
    self.titlebarTimer = [NSTimer scheduledTimerWithTimeInterval:kHideTitlebarTimerInterval target:self selector:@selector(hideTitlebar) userInfo:nil repeats:YES];
}

- (void)viewDidMoveToWindow
{
    [super viewDidMoveToWindow];
    
    [self setupHideTitlebarTimer];
}

- (void)hideTitlebar
{
    if (![self _mouseInNoHideArea] && [self canHideControls] && !(self.window.styleMask & NSFullScreenWindowMask)) {
        [self.playerWindow hideTitlebarAnimated:YES];
    }
    
    [self.titlebarTimer invalidate];
}

- (void)mouseMoved:(NSEvent *)theEvent
{
    [super mouseMoved:theEvent];
    
    [self.playerWindow showTitlebarAnimated:YES];
    [self setupHideTitlebarTimer];
}

- (void)mouseExited:(NSEvent *)theEvent
{
    [super mouseExited:theEvent];
    
    [self hideTitlebar];
}

- (void)mouseUp:(NSEvent *)theEvent
{
    [super mouseUp:theEvent];
    
    if (theEvent.clickCount == 2) {
        if ([self.window.windowController respondsToSelector:@selector(toggleFullScreen:)]) {
            [self.window.windowController toggleFullScreen:self];
        }
    }
}

- (GRPlayerWindow *)playerWindow
{
    return (GRPlayerWindow *)self.window;
}

@end
