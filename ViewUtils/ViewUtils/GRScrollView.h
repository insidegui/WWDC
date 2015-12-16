//
//  GRScrollView.h
//  ViewUtils
//
//  Created by Guilherme Rambo on 10/3/15.
//  Copyright © 2015 Guilherme Rambo. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class GRScrollView;

@protocol GRScrollViewDelegate <NSObject>

- (void)scrollViewDidScroll:(GRScrollView *__nonnull)scrollView;
- (void)scrollViewDidEndDragging:(GRScrollView *__nonnull)scrollView;
- (void)mouseWheelDidScroll:(GRScrollView *__nonnull)scrollView;

@end

@interface GRScrollView : NSScrollView

@property (nonatomic) CGPoint contentOffset;

@property (assign) id<GRScrollViewDelegate> __nullable delegate;

@end
