//
//  GRPlayerView.m
//  WWDCAppKit
//
//  Created by Guilherme Rambo on 19/04/15.
//  Copyright (c) 2015 Guilherme Rambo. All rights reserved.
//

#import "GRPlayerView.h"
#import "GRPlayerWindow.h"

@import AVFoundation;

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
{
    float _storedRate;
    NSView *_controlsContainerView;
}

- (void)setupHideTitlebarTimer
{
    [self.titlebarTimer invalidate];
    self.titlebarTimer = [NSTimer scheduledTimerWithTimeInterval:kHideTitlebarTimerInterval target:self selector:@selector(hideTitlebar) userInfo:nil repeats:YES];
}

- (void)viewDidMoveToWindow
{
    [super viewDidMoveToWindow];
    
    _storedRate = 1.0;
    
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

- (NSView *)controlsContainerView
{
    if (!_controlsContainerView) {
        for (NSView *subview in self.subviews) {
            for (NSView *view in subview.subviews) {
                if ([view isKindOfClass:NSClassFromString(@"AVMovableView")]) {
                    _controlsContainerView = view;
                    break;
                }
            }
        }
    }
    
    return _controlsContainerView;
}

- (IBAction)changePlaybackRate:(id)sender
{
    if (self.player.rate == 0) return;
    
    if (self.player.rate == 1.0) {
        self.player.rate = 1.5;
    } else if (self.player.rate == 1.5) {
        self.player.rate = 2.0;
    } else if (self.player.rate == 2.0) {
        self.player.rate = 0.5;
    } else if (self.player.rate == 0.5) {
        self.player.rate = 1.0;
    }
}

- (GRPlayerWindow *)playerWindow
{
    return (GRPlayerWindow *)self.window;
}

@end
