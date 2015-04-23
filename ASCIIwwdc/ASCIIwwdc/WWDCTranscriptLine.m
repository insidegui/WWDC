//
//  WWDCTranscriptLine.m
//  ASCIIwwdc
//
//  Created by Guilherme Rambo on 23/04/15.
//  Copyright (c) 2015 Guilherme Rambo. All rights reserved.
//

#import "WWDCTranscriptLine.h"

@implementation WWDCTranscriptLine

- (NSString *)description
{
    return [NSString stringWithFormat:@"<WWDCTranscriptLine> text = %@ | timecode = %f", self.text, self.timecode];
}

+ (NSString *)roundedStringFromTimecode:(double)timecode
{
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    [formatter setPositiveFormat:@"0.#"];
    
    return [formatter stringFromNumber:@(timecode)];
}

- (NSString *)timecodeAsRoundedString
{
    return [WWDCTranscriptLine roundedStringFromTimecode:self.timecode];
}

@end
