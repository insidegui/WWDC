//
//  GRActionableProgressIndicator.m
//  WWDCAppKit
//
//  Created by Guilherme Rambo on 01/05/15.
//  Copyright (c) 2015 Guilherme Rambo. All rights reserved.
//

#import "GRActionableProgressIndicator.h"

@implementation GRActionableProgressIndicator

- (void)mouseUp:(NSEvent *)theEvent
{
    if (theEvent.clickCount == 1) {
        if (self.action) [[NSApplication sharedApplication] sendAction:self.action to:self.target from:self];
    } else if (theEvent.clickCount == 2) {
        if (self.doubleAction) [[NSApplication sharedApplication] sendAction:self.doubleAction to:self.target from:self];
    }
    
    [super mouseUp:theEvent];
}

@end
