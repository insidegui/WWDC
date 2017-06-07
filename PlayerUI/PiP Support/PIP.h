//
//  PIP.h
//  PiP Client
//
//  Created by Guilherme Rambo on 30/10/16.
//  Copyright © 2016 Guilherme Rambo. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class PIPViewController;

@protocol PIPViewControllerDelegate <NSObject>

@optional
- (void)pipActionStop:(PIPViewController *__nonnull)pip;
- (void)pipActionPause:(PIPViewController *__nonnull)pip;
- (void)pipActionPlay:(PIPViewController *__nonnull)pip;
- (void)pipActionReturn:(PIPViewController *__nonnull)pip;
- (void)pipDidClose:(PIPViewController *__nonnull)pip;
- (void)pipWillClose:(PIPViewController *__nonnull)pip;
@end

@interface PIPViewController : NSViewController

@property (nonatomic, weak) id <PIPViewControllerDelegate> __nullable delegate;
@property (nonatomic, assign) NSRect replacementRect;
@property (nonatomic, weak) NSWindow *__nullable replacementWindow;
@property (nonatomic, weak) NSView *__nullable replacementView;
@property (nonatomic, copy) NSString *__nullable name;
@property (nonatomic, assign) NSSize aspectRatio;

- (void)presentViewControllerAsPictureInPicture:(__kindof NSViewController *__nonnull)controller;
- (void)setPlaying:(BOOL)playing;
- (BOOL)playing;

- (instancetype __nonnull)init;

@end
