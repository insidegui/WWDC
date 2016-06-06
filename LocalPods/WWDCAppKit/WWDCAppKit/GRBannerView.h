//
//  GRBannerView.h
//  WWDCAppKit
//
//  Created by Guilherme Rambo on 09/06/15.
//  Copyright (c) 2015 Guilherme Rambo. All rights reserved.
//

#import <Cocoa/Cocoa.h>

IB_DESIGNABLE
@interface GRBannerView : NSView

@property (nonatomic, copy) IBInspectable NSColor *backgroundColor;
@property (nonatomic, copy) IBInspectable NSColor *separatorColor;

@end
