//
//  GRPlayerView.m
//  ViewUtils
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

@property (readonly) NSView *controlsContainerView;
@property (strong) NSButton *speedButton;

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
    [self setupExtraControls];
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

- (void)setSpeedButtonTitleForRate:(float)rate
{
    if (rate <= 0) return;

    if (rate - (int)rate != 0) {
        [self setSpeedButtonTitle:[NSString stringWithFormat:@"%.1fx", rate]];
    } else {
        [self setSpeedButtonTitle:[NSString stringWithFormat:@"%.0fx", rate]];
    }
    
}

- (void)setSpeedButtonTitle:(NSString *)title
{
    NSMutableParagraphStyle *pStyle = [[NSMutableParagraphStyle alloc] init];
    pStyle.alignment = NSCenterTextAlignment;
    NSDictionary *attrs = @{
                            NSForegroundColorAttributeName: [NSColor labelColor],
                            NSParagraphStyleAttributeName: pStyle};
    self.speedButton.attributedTitle = [[NSAttributedString alloc] initWithString:title attributes:attrs];
}

- (void)setupExtraControls
{
    self.speedButton = [[NSButton alloc] initWithFrame:NSMakeRect(360.0, 31.0, 32.0, 22.0)];
    NSButtonCell *buttonCell = self.speedButton.cell;
    buttonCell.highlightsBy = 12;
    self.speedButton.bordered = NO;
    self.speedButton.appearance = [NSAppearance appearanceNamed:NSAppearanceNameVibrantDark];
    self.speedButton.bezelStyle = NSRoundedBezelStyle;
    self.speedButton.target = self;
    self.speedButton.action = @selector(speedButtonAction:);
    [self setSpeedButtonTitle:@"1x"];
    [self.controlsContainerView addSubview:self.speedButton];
}

- (void)speedButtonAction:(id)sender
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

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSString *,id> *)change context:(void *)context
{
    if ([keyPath isEqualToString:@"playerController.playing"]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self setSpeedButtonTitleForRate:self.player.rate];
        });
    }
    
    [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}

- (GRPlayerWindow *)playerWindow
{
    return (GRPlayerWindow *)self.window;
}

@end
