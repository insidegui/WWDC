//
//  GRCustomPlayerView.m
//  WWDCAppKit
//
//  Created by Guilherme Rambo on 10/06/15.
//  Copyright (c) 2015 Guilherme Rambo. All rights reserved.
//

#import "GRCustomPlayerView.h"

@import AVFoundation;
@import QuartzCore;

@interface GRCustomPlayerView ()

@property (copy) NSString *infoText;
@property (strong) CATextLayer *infoTextLayer;

@end

@implementation GRCustomPlayerView

- (instancetype)initWithFrame:(NSRect)frameRect
{
    if (!(self = [super initWithFrame:frameRect])) return nil;
    
    [self _gr_commonInit];
    
    return self;
}

- (void)awakeFromNib
{
    [self _gr_commonInit];
}

- (void)_gr_commonInit
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        self.wantsLayer = YES;
        self.layer = [CALayer layer];
        self.layer.backgroundColor = [NSColor blackColor].CGColor;
    });
}

- (void)setPlayer:(AVPlayer *)player
{
    _player = player;
    
    self.layer = [AVPlayerLayer playerLayerWithPlayer:_player];
}

- (void)play
{
    [self.player play];
}

- (void)pause
{
    [self.player pause];
}

- (void)keyDown:(NSEvent *)theEvent
{
    return;
}

- (void)keyUp:(NSEvent *)theEvent
{
    if (theEvent.keyCode == 49) {
        if (self.player.rate > 0) {
            [self.player pause];
        } else {
            [self.player play];
        }
    } else {
        [super keyUp:theEvent];
    }
}

- (BOOL)acceptsFirstMouse:(NSEvent *)theEvent
{
    return YES;
}

- (BOOL)acceptsFirstResponder
{
    return YES;
}

@end
