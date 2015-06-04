//
//  main.m
//  wwdctranscriptindex
//
//  Created by Guilherme Rambo on 04/06/15.
//  Copyright (c) 2015 Guilherme Rambo. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "ASCIIWWDCTranscriptIndexer.h"

NSArray *demangledSessionListFromArgument(NSString *arg);

int main(int argc, const char * argv[]) {
    if (argc < 2) {
        printf("Example: wwdctranscriptindex 2014/101,2014/204,2014/205\n");
        return 1;
    }
    
    @autoreleasepool {
        NSArray *sessions = demangledSessionListFromArgument([NSString stringWithUTF8String:argv[1]]);
        
        [[ASCIIWWDCTranscriptIndexer sharedIndexer] setIndexCompletionHandler:^{
            NSLog(@"COMPLETED");
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                exit(0);
            });
        }];
        [[ASCIIWWDCTranscriptIndexer sharedIndexer] indexSessions:sessions];
        
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate distantFuture]];
    }
    
    return 0;
}

NSArray *demangledSessionListFromArgument(NSString *arg)
{
    NSMutableArray *resultingList = [[NSMutableArray alloc] init];
    
    NSArray *list = [arg componentsSeparatedByString:@","];
    for (NSString *sessionToken in list) {
        NSArray *sessionInfo = [sessionToken componentsSeparatedByString:@"/"];
        if (sessionInfo.count < 2) continue;
        
        [resultingList addObject:@{
                                   @"year": @([sessionInfo[0] intValue]),
                                   @"id": @([sessionInfo[1] intValue]),
                                   }];
    }
    
    return [resultingList copy];
}