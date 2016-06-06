//
//  GRWindow.h
//  WWDCAppKit
//
//  Created by Guilherme Rambo on 20/04/15.
//  Copyright (c) 2015 Guilherme Rambo. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface GRWindow : NSWindow

@property (readonly) NSVisualEffectView *titlebarView;
@property (readonly) BOOL titlebarVisible;

- (void)hideTitlebarAnimated:(BOOL)animated;
- (void)showTitlebarAnimated:(BOOL)animated;

@end

// this is just a hack so we can access titlebarView without warnings from the compiler,
// titlebarView is actually a property of NSThemeFrame, which is a subclass of NSView ;)
@interface NSView (Titlebar)
- (NSVisualEffectView *)titlebarView;
@end