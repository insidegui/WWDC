//
//  WWDCSessionTranscript.h
//  ASCIIwwdc
//
//  Created by Guilherme Rambo on 23/04/15.
//  Copyright (c) 2015 Guilherme Rambo. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface WWDCSessionTranscript : NSObject <NSSecureCoding>

@property (assign) int year;
@property (assign) int session;
@property (strong) NSArray *lines;

@property (readonly) NSString *fullText;
@property (readonly) NSString *htmlString;

@property (readonly) NSArray<NSValue *> *timecodes;

@end
