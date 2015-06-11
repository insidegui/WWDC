//
//  GRTitlebarVisibilityControllingView.m
//  
//
//  Created by Guilherme Rambo on 10/06/15.
//
//

#import "GRTitlebarVisibilityControllingView.h"

#import "GRPlayerWindow.h"

@interface GRTitlebarVisibilityControllingView ()

@property (readonly) GRPlayerWindow *playerWindow;
@property (strong) NSTimer *titlebarTimer;

@end

#define kHideTitlebarTimerInterval 3.0f

@implementation GRTitlebarVisibilityControllingView
{
    NSTrackingArea *_mouseTrackingArea;
}

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
    if (!(self.window.styleMask & NSFullScreenWindowMask)) {
        [self.playerWindow hideTitlebarAnimated:YES];
    }
    
    [self.titlebarTimer invalidate];
}

- (void)updateTrackingAreas
{
    if (_mouseTrackingArea) [self removeTrackingArea:_mouseTrackingArea];
    
    _mouseTrackingArea = [[NSTrackingArea alloc] initWithRect:self.bounds options:NSTrackingActiveAlways|NSTrackingMouseEnteredAndExited|NSTrackingMouseMoved owner:self userInfo:nil];
    [self addTrackingArea:_mouseTrackingArea];
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
