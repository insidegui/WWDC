//
//  GRMovableVisualEffectView.m
//  ViewUtils
//
//  Created by Guilherme Rambo on 26/09/15.
//  Copyright © 2015 Guilherme Rambo. All rights reserved.
//

#import "GRMovableVisualEffectView.h"

#import "GRWindowMovingView.h"

@implementation GRMovableVisualEffectView

- (void)mouseDown:(NSEvent *)theEvent
{
    NSPoint point = NSMakePoint(theEvent.locationInWindow.x, NSHeight(self.window.frame)-theEvent.locationInWindow.y);
    
    if ([NSEvent pressedMouseButtons] & 1) {
        CGSDragWindowRelativeToMouse(CGSMainConnectionID(), (CGWindowID)self.window.windowNumber, point);
    }
}

- (BOOL)acceptsFirstMouse:(NSEvent *)theEvent
{
    return YES;
}

@end
