//
//  VXPlayerWindow.h
//  VLCX
//
//  Created by Guilherme Rambo on 15/12/14.
//  Copyright (c) 2014 Guilherme Rambo. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface GRPlayerWindow : NSWindow

@property (readonly) BOOL titlebarVisible;

- (void)hideTitlebarAnimated:(BOOL)animated;
- (void)showTitlebarAnimated:(BOOL)animated;

@end
