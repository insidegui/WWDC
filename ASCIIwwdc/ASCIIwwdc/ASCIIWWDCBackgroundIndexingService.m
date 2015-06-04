//
//  ASCIWWDCBackgroundIndexingService.m
//  ASCIIwwdc
//
//  Created by Guilherme Rambo on 04/06/15.
//  Copyright (c) 2015 Guilherme Rambo. All rights reserved.
//

#import "ASCIIWWDCBackgroundIndexingService.h"

#import "NTBTask.h"

#define kIndexProgramName @"wwdctranscriptindex"
#define kQueueName "ASCIIWWDC Queue"

@interface ASCIIWWDCBackgroundIndexingServiceImpl : NSObject

+ (ASCIIWWDCBackgroundIndexingServiceImpl *)defaultImpl;
- (void)runWithSessions:(NSArray *)sessions;

@property (assign) BOOL hasIndex;

@end

@implementation ASCIIWWDCBackgroundIndexingService

+ (void)runWithSessions:(NSArray *)sessions
{
    [[ASCIIWWDCBackgroundIndexingServiceImpl defaultImpl] runWithSessions:sessions];
}

+ (BOOL)hasIndex
{
    return [ASCIIWWDCBackgroundIndexingServiceImpl defaultImpl].hasIndex;
}

@end

@implementation ASCIIWWDCBackgroundIndexingServiceImpl

+ (ASCIIWWDCBackgroundIndexingServiceImpl *)defaultImpl
{
    static ASCIIWWDCBackgroundIndexingServiceImpl *_instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [[ASCIIWWDCBackgroundIndexingServiceImpl alloc] init];
    });
    return _instance;
}

- (void)runWithSessions:(NSArray *)sessions
{
    dispatch_queue_t bgQ = dispatch_queue_create(kQueueName, NULL);
    dispatch_async(bgQ, ^{
        NTBTask *task = [[NTBTask alloc] initWithLaunchPath:[self launchPath]];
        task.arguments = @[[self mangleSessionList:sessions]];
        NSString *output = [task waitForOutputString];
        
        if (task.terminationStatus != 0) {
            NSLog(@"[ASCIIWWDCBackgroundIndexingServiceImpl] %@ failed with exit status %d", kIndexProgramName, task.terminationStatus);
            NSLog(@"%@", output);
            self.hasIndex = NO;
        } else {
            #ifdef DEBUG
            NSLog(@"[ASCIIWWDCBackgroundIndexingServiceImpl] %@ finished!", kIndexProgramName);
            #endif
            self.hasIndex = YES;
        }
    });
}

- (NSString *)launchPath
{
    return [[NSBundle bundleForClass:[self class]] pathForResource:kIndexProgramName ofType:@""];
}

- (NSString *)mangleSessionList:(NSArray *)sessions
{
    NSMutableString *output = [[NSMutableString alloc] init];
    
    for (NSDictionary *sessionDict in sessions) {
        [output appendFormat:@"%@/%@,", sessionDict[@"year"], sessionDict[@"id"]];
    }
    
    return [output copy];
}

@end