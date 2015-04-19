//
//  GRWindowMovingView.m
//  GRWindowMovingView
//
//  Created by Guilherme Rambo on 19/04/15.
//  Copyright (c) 2015 Guilherme Rambo. All rights reserved.
//

#import "GRWindowMovingView.h"

typedef int CGSConnectionID;

extern CGSConnectionID CGSMainConnectionID(void);
extern CGError CGSDragWindowRelativeToMouse(CGSConnectionID cid, CGWindowID wid, CGPoint point);

@implementation GRWindowMovingView

- (void)drawRect:(NSRect)dirtyRect
{
    [super drawRect:dirtyRect];
    
    if (self.backgroundColor) {
        [self.backgroundColor setFill];
        NSRectFill(dirtyRect);
    }
}

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

- (void)setBackgroundColor:(NSColor *)backgroundColor
{
    _backgroundColor = [backgroundColor copy];
    
    [self setNeedsDisplay:YES];
}

@end
