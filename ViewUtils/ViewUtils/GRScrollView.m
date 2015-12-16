//
//  GRScrollView.m
//  ViewUtils
//
//  Created by Guilherme Rambo on 10/3/15.
//  Copyright © 2015 Guilherme Rambo. All rights reserved.
//

#import "GRScrollView.h"

@implementation GRScrollView

- (void)scrollWheel:(NSEvent *)theEvent
{
    [super scrollWheel:theEvent];
    
    if (theEvent.phase == NSEventPhaseNone && theEvent.momentumPhase == NSEventPhaseNone && [self.delegate respondsToSelector:@selector(mouseWheelDidScroll:)]) {
        [self.delegate mouseWheelDidScroll:self];
        return;
    }
    
    if (theEvent.phase == NSEventPhaseEnded && theEvent.deltaX == 0.0 && theEvent.deltaY == 0.0) if ([self.delegate respondsToSelector:@selector(scrollViewDidEndDragging:)]) [self.delegate scrollViewDidEndDragging:self];
    if ([self.delegate respondsToSelector:@selector(scrollViewDidScroll:)]) [self.delegate scrollViewDidScroll:self];
}

- (CGPoint)contentOffset
{
    return self.contentView.bounds.origin;
}

@end
