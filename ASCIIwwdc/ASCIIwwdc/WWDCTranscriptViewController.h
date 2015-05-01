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

@property (nonatomic, assign) NSInteger year;
@property (nonatomic, assign) NSInteger session;

@property (nonatomic, copy) void (^jumpToTimecodeCallback)(double timecode);
@property (nonatomic, copy) void (^transcriptAvailableCallback)(WWDCSessionTranscript *transcript);

+ (WWDCTranscriptViewController *)transcriptViewControllerWithYear:(NSInteger)year session:(NSInteger)session;

- (void)highlightLineAt:(NSString *)roundedTimecode;
- (void)searchFor:(NSString *)term;

@end
