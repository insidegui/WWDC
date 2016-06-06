//
//  GRLoadingView.m
//  WWDCAppKit
//
//  Created by Guilherme Rambo on 08/05/15.
//  Copyright (c) 2015 Guilherme Rambo. All rights reserved.
//

#import "GRLoadingView.h"

@interface GRLoadingViewCoordinator : NSObject

+ (GRLoadingViewCoordinator *)sharedCoordinator;
- (void)addLoadingView:(GRLoadingView *)view;
- (void)removeLoadingView:(GRLoadingView *)view;
- (void)dismissAll;
- (void)dismissAllAfterDelay:(NSTimeInterval)delay;

@end

@interface GRLoadingView ()

@property (unsafe_unretained) NSWindow *containerWindow;

@property (strong) NSProgressIndicator *progressIndicator;

@end

@implementation GRLoadingView

+ (GRLoadingView *)showInWindow:(NSWindow *)window
{
    NSRect contentViewRect = [window.contentView frame];
    
    GRLoadingView *view = [[GRLoadingView alloc] initWithFrame:NSMakeRect(0, 0, NSWidth(contentViewRect), NSHeight(contentViewRect))];
    
    [[GRLoadingViewCoordinator sharedCoordinator] addLoadingView:view];
    
    view.containerWindow = window;
    
    [view open];
    
    return view;
}

+ (void)dismissAll
{
    [[GRLoadingViewCoordinator sharedCoordinator] dismissAll];
}

+ (void)dismissAllAfterDelay:(NSTimeInterval)delay
{
    [[GRLoadingViewCoordinator sharedCoordinator] dismissAllAfterDelay:delay];
}

- (void)open
{
    NSArray *contentViewSubviews = [self.containerWindow.contentView subviews];
    NSView *lastView = contentViewSubviews.lastObject;
    self.alphaValue = 0;
    [self.containerWindow.contentView addSubview:self positioned:NSWindowAbove relativeTo:lastView];
    
    [self _setupLoadingViewLayout];
    [self.progressIndicator startAnimation:nil];
    
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
        self.animator.alphaValue = 1;
    } completionHandler:^{}];
}

- (void)dismiss
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
        self.animator.alphaValue = 0;
    } completionHandler:^{
        [self removeFromSuperview];
        [[GRLoadingViewCoordinator sharedCoordinator] removeLoadingView:self];
    }];
}

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    
    [[NSColor whiteColor] setFill];
    NSRectFill(dirtyRect);
}

- (void)_setupLoadingViewLayout
{
    self.autoresizingMask = NSViewWidthSizable|NSViewHeightSizable;
    self.progressIndicator = [[NSProgressIndicator alloc] initWithFrame:[self _progressIndicatorFrame]];
    
    [self.progressIndicator setIndeterminate:YES];
    [self.progressIndicator setControlSize:NSRegularControlSize];
    [self.progressIndicator setStyle:NSProgressIndicatorSpinningStyle];

    [self addSubview:self.progressIndicator];
    
    [self setPostsFrameChangedNotifications:YES];
    [[NSNotificationCenter defaultCenter] addObserverForName:NSViewFrameDidChangeNotification object:self queue:nil usingBlock:^(NSNotification *note) {
        self.progressIndicator.frame = [self _progressIndicatorFrame];
    }];
}

- (NSRect)_progressIndicatorFrame
{
    return NSMakeRect(NSWidth(self.frame)/2-16, NSHeight(self.frame)/2-16, 32, 32);
}

@end

@implementation GRLoadingViewCoordinator
{
    __strong NSMutableArray *_loadingViews;
}

+ (GRLoadingViewCoordinator *)sharedCoordinator
{
    static GRLoadingViewCoordinator *_shared;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _shared = [[GRLoadingViewCoordinator alloc] init];
    });
    
    return _shared;
}

- (instancetype)init
{
    if (!(self = [super init])) return nil;
    
    _loadingViews = [[NSMutableArray alloc] init];
    
    return self;
}

- (void)addLoadingView:(GRLoadingView *)view
{
    [_loadingViews addObject:view];
}

- (void)removeLoadingView:(GRLoadingView *)view
{
    [_loadingViews removeObject:view];
}

- (void)dismissAll
{
    [_loadingViews makeObjectsPerformSelector:@selector(dismiss)];
}

- (void)dismissAllAfterDelay:(NSTimeInterval)delay
{
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self dismissAll];
    });
}

@end