//
//  GRSegmentedControl.h
//  ViewUtils
//
//  Created by Guilherme Rambo on 10/3/15.
//  Copyright © 2015 Guilherme Rambo. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface GRSegmentedControl : NSSegmentedControl

@property (nonatomic, copy) IBInspectable NSColor *__nullable borderColor;
@property (nonatomic, copy) IBInspectable NSColor *__nullable segmentTextColor;
@property (nonatomic, copy) IBInspectable NSColor *__nullable segmentBackgroundColor;
@property (nonatomic, copy) IBInspectable NSColor *__nullable activeSegmentTextColor;
@property (nonatomic, copy) IBInspectable NSColor *__nullable activeSegmentBackgroundColor;

@property (nonatomic, assign) BOOL showsMenuImmediately;
@property (nonatomic, assign) BOOL usesCocoaLook;

@end
