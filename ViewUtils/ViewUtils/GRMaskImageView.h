//
//  GRMaskImageView.h
//  ViewUtils
//
//  Created by Guilherme Rambo on 26/09/15.
//  Copyright © 2015 Guilherme Rambo. All rights reserved.
//

#import <Cocoa/Cocoa.h>

IB_DESIGNABLE
@interface GRMaskImageView : NSView

@property (nonatomic, copy) IBInspectable NSColor *__nullable backgroundColor;
@property (nonatomic, copy) IBInspectable NSColor *__nullable tintColor;
@property (nonatomic, strong) IBInspectable NSImage *__nullable image;

@end
