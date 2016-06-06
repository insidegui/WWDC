//
//  GRWindowMovingView.h
//  GRWindowMovingView
//
//  Created by Guilherme Rambo on 19/04/15.
//  Copyright (c) 2015 Guilherme Rambo. All rights reserved.
//

#import <Cocoa/Cocoa.h>

typedef int CGSConnectionID;

extern CGSConnectionID CGSMainConnectionID(void);
extern CGError CGSDragWindowRelativeToMouse(CGSConnectionID cid, CGWindowID wid, CGPoint point);

IB_DESIGNABLE
@interface GRWindowMovingView : NSView

@property (nonatomic, copy) IBInspectable NSColor *backgroundColor;

@end
