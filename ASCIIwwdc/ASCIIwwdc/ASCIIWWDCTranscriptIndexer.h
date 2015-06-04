//
//  ASCIIWWDCTranscriptIndexer.h
//  ASCIIWWDC Indexer
//
//  Created by Guilherme Rambo on 01/06/15.
//  Copyright (c) 2015 Guilherme Rambo. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ASCIIWWDCTranscriptIndexer : NSObject

+ (ASCIIWWDCTranscriptIndexer  * __nonnull )sharedIndexer;

- (void)indexSessions:(NSArray *__nonnull)sessions;

- (BOOL)fullTextSearchFor:(NSString * __nonnull)query matches:(NSString * __nonnull)sessionUniqueKey;

@property (nonatomic, copy) void (^__nullable indexCompletionHandler)();

@end
