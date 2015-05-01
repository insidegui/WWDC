//
//  WWDCSessionTranscript.h
//  ASCIIwwdc
//
//  Created by Guilherme Rambo on 23/04/15.
//  Copyright (c) 2015 Guilherme Rambo. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
@interface WWDCSessionTranscript : NSObject

@property (assign) NSInteger year;
@property (assign) NSInteger sessionID;
@property (strong, nullable) NSArray *lines;
@property (readonly, nullable) NSString *htmlString;
@property (readonly, nullable) NSArray *timecodes;

@end
NS_ASSUME_NONNULL_END
