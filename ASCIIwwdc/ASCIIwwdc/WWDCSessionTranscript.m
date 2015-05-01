//
//  WWDCSessionTranscript.m
//  ASCIIwwdc
//
//  Created by Guilherme Rambo on 23/04/15.
//  Copyright (c) 2015 Guilherme Rambo. All rights reserved.
//

#import "WWDCSessionTranscript.h"

#import "WWDCTranscriptLine.h"
#import "WWDCTranscriptWebUtils.h"

@import AVFoundation;

@implementation WWDCSessionTranscript
{
    __strong NSString *_baseHTMLString;
    __strong NSString *_cachedHTMLString;
}

// FIXME: somehow there's an NSInvalidArgumentException if not to synthesize _this_ property
@synthesize sessionID;

- (NSString *)htmlString
{
    if (!_cachedHTMLString) [self _computeHTMLString];
    
    return _cachedHTMLString;
}

#define kTranscriptLineFormat @"<a href=\"javascript:controller.jumpToTimecode(%f)\" data-timecode=\"%@\">%@</a>\n"

- (void)_computeHTMLString
{
    if (!_baseHTMLString) _baseHTMLString = [[NSString alloc] initWithContentsOfURL:[WWDCTranscriptWebUtils htmlURL] encoding:NSUTF8StringEncoding error:nil];
    
    NSMutableString *html = [[NSMutableString alloc] init];
    
    for (WWDCTranscriptLine *line in self.lines) {
        [html appendFormat:kTranscriptLineFormat, line.timecode, line.timecodeAsRoundedString, line.text];
    }
    
    _cachedHTMLString = [NSString stringWithFormat:_baseHTMLString, html];
}

- (NSArray *)timecodes
{
    NSMutableArray *timecodes = [[NSMutableArray alloc] initWithCapacity:self.lines.count];
    
    for (WWDCTranscriptLine *line in self.lines) {
        [timecodes addObject:[NSValue valueWithCMTime:CMTimeMakeWithSeconds(line.timecode, 60)]];
    }
    
    return [timecodes copy];
}

@end
