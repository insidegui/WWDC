//
//  WWDCTranscriptViewController.h
//  ASCIIwwdc
//
//  Created by Guilherme Rambo on 23/04/15.
//  Copyright (c) 2015 Guilherme Rambo. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class WWDCSessionTranscript;

@interface WWDCTranscriptViewController : NSViewController

@property (nonatomic, assign) int year;
@property (nonatomic, assign) int session;

@property (nonatomic, copy) void (^jumpToTimecodeCallback)(double timecode);
@property (nonatomic, copy) void (^transcriptAvailableCallback)(WWDCSessionTranscript *transcript);

+ (WWDCTranscriptViewController *)transcriptViewControllerWithYear:(int)year session:(int)session;

- (void)highlightLineAt:(NSString *)roundedTimecode;
- (void)searchFor:(NSString *)term;

@property (nonatomic, copy) NSFont *font;
@property (nonatomic, copy) NSColor *textColor;
@property (nonatomic, copy) NSColor *backgroundColor;

@end
