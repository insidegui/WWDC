//
//  GRPlayerWindow.m
//
//  Created by Guilherme Rambo on 15/12/14.
//  Copyright (c) 2014 Guilherme Rambo. All rights reserved.
//

#import "GRPlayerWindow.h"

@implementation GRPlayerWindow

- (void)configureTitlebar
{
    self.titlebarView.material = NSVisualEffectMaterialDark;
    self.titlebarView.state = NSVisualEffectStateActive;
}

- (void)sizeToFitVideoSize:(NSSize)videoSize ignoringScreenSize:(BOOL)ignoreScreen animated:(BOOL)animate
{
    CGFloat wRatio, hRatio, resizeRatio;
    NSRect screenRect = [NSScreen mainScreen].frame;
    NSSize screenSize = screenRect.size;
    
    if (videoSize.width >= videoSize.height) {
        wRatio = screenSize.width / videoSize.width;
        hRatio = screenSize.height / videoSize.height;
    } else {
        wRatio = screenSize.height / videoSize.width;
        hRatio = screenSize.width / videoSize.height;
    }
    
    resizeRatio = MIN(wRatio, hRatio);
    
    NSSize newSize = NSMakeSize(videoSize.width*resizeRatio, videoSize.height*resizeRatio);
    
    if (ignoreScreen) {
        newSize.width = videoSize.width;
        newSize.height = videoSize.height;
    }
    
    NSRect newRect = NSMakeRect(screenSize.width/2-newSize.width/2, screenSize.height/2-newSize.height/2, newSize.width, newSize.height);

    [self setFrame:newRect display:YES animate:animate];
    
    if (!animate) [self center];
}

@end