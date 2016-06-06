//
//  GRLoadingView.h
//  WWDCAppKit
//
//  Created by Guilherme Rambo on 08/05/15.
//  Copyright (c) 2015 Guilherme Rambo. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "GRWindowMovingView.h"

@interface GRLoadingView : GRWindowMovingView

+ (GRLoadingView *)showInWindow:(NSWindow *)window;
+ (void)dismissAll;
+ (void)dismissAllAfterDelay:(NSTimeInterval)delay;

- (void)dismiss;

@end
