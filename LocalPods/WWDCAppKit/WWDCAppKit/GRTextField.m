//
//  GRTextField.m
//  WWDCAppKit
//
//  Created by Guilherme Rambo on 23/04/15.
//  Copyright (c) 2015 Guilherme Rambo. All rights reserved.
//

#import "GRTextField.h"

@implementation GRTextField

#define kGRTextFieldRightMarginToSuperview 32.0f

// From: http://stackoverflow.com/a/10463761/2271555
- (NSSize)intrinsicContentSize
{
    if ( ![self.cell wraps] ) {
        return [super intrinsicContentSize];
    }
    
    NSRect frame = [self frame];
    
    CGFloat width = self.superview.frame.size.width-kGRTextFieldRightMarginToSuperview;

    frame.size.height = CGFLOAT_MAX;

    CGFloat height = [self.cell cellSizeForBounds: frame].height;
    
    return NSMakeSize(width, height);
}

- (void)awakeFromNib
{
    [super awakeFromNib];
    
    self.superview.postsFrameChangedNotifications = YES;
    [[NSNotificationCenter defaultCenter] addObserverForName:NSViewFrameDidChangeNotification object:self.superview queue:nil usingBlock:^(NSNotification *note) {
        [self invalidateIntrinsicContentSize];
    }];
}

- (void)textDidChange:(NSNotification *)notification
{
    [super textDidChange:notification];
    [self invalidateIntrinsicContentSize];
}

@end
