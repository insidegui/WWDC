//
//  GRCustomPlayerView.h
//  WWDCAppKit
//
//  Created by Guilherme Rambo on 10/06/15.
//  Copyright (c) 2015 Guilherme Rambo. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "GRTitlebarVisibilityControllingView.h"

@class AVPlayer;

@interface GRCustomPlayerView : GRTitlebarVisibilityControllingView

@property (nonatomic, strong) AVPlayer *player;

- (void)play;
- (void)pause;

@end
