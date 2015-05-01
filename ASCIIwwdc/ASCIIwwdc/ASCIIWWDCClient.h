//
//  ASCIIWWDCClient.h
//  ASCIIwwdc
//
//  Created by Guilherme Rambo on 23/04/15.
//  Copyright (c) 2015 Guilherme Rambo. All rights reserved.
//

#import <Foundation/Foundation.h>

@class WWDCSessionTranscript;

typedef void (^ASCIIWWDCClientCallback)(BOOL, WWDCSessionTranscript * __nullable);
typedef void (^ASCIIWWDCClientArrayCallback)(BOOL, NSArray * __nullable);

NS_ASSUME_NONNULL_BEGIN
@interface ASCIIWWDCClient : NSObject

+ (ASCIIWWDCClient *)sharedClient;

- (void)fetchTranscriptForYear:(NSInteger)year
					 sessionID:(NSInteger)sessionID
			 completionHandler:(ASCIIWWDCClientCallback)callback;
- (void)fetchTranscriptsForQuery:(NSString *)query
			   completionHandler:(ASCIIWWDCClientArrayCallback)callback;

@end
NS_ASSUME_NONNULL_END
