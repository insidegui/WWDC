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

#pragma mark NSSecureCoding

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    if (!(self = [super init])) return nil;
    
    self.text = [aDecoder decodeObjectForKey:@"text"];
    self.timecode = [aDecoder decodeDoubleForKey:@"timecode"];
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:self.text forKey:@"text"];
    [aCoder encodeDouble:self.timecode forKey:@"timecode"];
}

@end
