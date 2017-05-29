//
//  NSToolbarItemViewer+Overrides.m
//  WWDC
//
//  Created by Guilherme Rambo on 15/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

@import Cocoa;

@interface NSToolbarItemViewer: NSView
@end

@implementation NSToolbarItemViewer (Overrides)

- (BOOL)_shouldDrawSelectionIndicator
{
    return NO;
}

@end
