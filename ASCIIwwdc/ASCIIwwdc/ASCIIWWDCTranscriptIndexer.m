//
//  ASCIIWWDCTranscriptIndexer.m
//  ASCIIWWDC Indexer
//
//  Created by Guilherme Rambo on 01/06/15.
//  Copyright (c) 2015 Guilherme Rambo. All rights reserved.
//

#import "ASCIIWWDCTranscriptIndexer.h"
#import "ASCIIWWDCClient.h"
#import "WWDCSessionTranscript.h"
#import "YapDatabase.h"
#import "YapDatabaseFullTextSearch.h"

#define kIndexingQueueName "WWDC Transcript Indexing"
#define kDatabaseAppFolderName @"WWDC"
#define kDatabaseFilename @"transcripts.sqlite"
#define kCollectionName @"transcripts"

#ifdef DEBUG
#define DEBUG_INDEXING
#endif

@interface ASCIIWWDCTranscriptIndexer ()

@property (readonly) NSString *databasePath;
@property (strong) YapDatabase *database;
@property (strong) YapDatabaseConnection *connection;

@property (assign) int transcriptsToProcess;
@property (assign) int processedTranscripts;

@end

@implementation ASCIIWWDCTranscriptIndexer

+ (ASCIIWWDCTranscriptIndexer *)sharedIndexer
{
    static ASCIIWWDCTranscriptIndexer *_sharedInstance;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedInstance = [[ASCIIWWDCTranscriptIndexer alloc] init];
    });
    
    return _sharedInstance;
}

- (void)indexSessions:(NSArray *__nonnull)sessions
{
    self.transcriptsToProcess = 0;
    self.processedTranscripts = 0;
    
    if ([self indexMatches:sessions]) {
        #ifdef DEBUG_INDEXING
        NSLog(@"[ASCIIWWDCTranscriptIndexer] Index is up to date");
        [self checkForCompletionIgnoringStats:YES];
        #endif
        return;
    }
    
    dispatch_queue_t indexingQ = dispatch_queue_create("WWDC Transcript Indexing", NULL);
    dispatch_async(indexingQ, ^{
        [sessions enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            @autoreleasepool {
                self.transcriptsToProcess++;
                NSNumber *year = [obj objectForKey:@"year"];
                NSNumber *sessionId = [obj objectForKey:@"id"];
                [self indexTranscriptForYear:year session:sessionId];
            }
        }];
    });
}

- (BOOL)fullTextSearchFor:(NSString * __nonnull)query matches:(NSString * __nonnull)sessionUniqueKey
{
    NSMutableArray *results = [[NSMutableArray alloc] init];
    
    [self.connection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
        [[transaction ext:@"fts"] enumerateKeysMatching:query usingBlock:^(NSString *collection, NSString *key, BOOL *stop) {
            [results addObject:key];
        }];
    }];
    
    return [results containsObject:sessionUniqueKey];
}

#pragma mark Private API

- (NSString *)databasePath
{
    NSArray *sp = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, NO);
    NSString *appFolderPath = [sp[0] stringByAppendingPathComponent:kDatabaseAppFolderName];
    if (![[NSFileManager defaultManager] fileExistsAtPath:appFolderPath]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:appFolderPath withIntermediateDirectories:NO attributes:nil error:nil];
    }
    
    return [appFolderPath stringByAppendingPathComponent:kDatabaseFilename];
}

- (instancetype)init
{
    if (!(self = [super init])) return nil;
    
    self.transcriptsToProcess = 0;
    self.processedTranscripts = 0;
    self.database = [[YapDatabase alloc] initWithPath:self.databasePath];
    self.connection = [self.database newConnection];
    
    [self setupFullTextSearch];
    
    return self;
}

- (void)setupFullTextSearch
{
    YapDatabaseFullTextSearchWithObjectBlock block = ^(NSMutableDictionary *dict, NSString *collection, NSString *key, id object) {
        if ([object isKindOfClass:[WWDCSessionTranscript class]]) {
            WWDCSessionTranscript *transcript = (WWDCSessionTranscript *)object;
            [dict setObject:transcript.fullText forKey:@"fullText"];
        }
    };
    
    YapDatabaseFullTextSearchHandler *handler = [YapDatabaseFullTextSearchHandler withObjectBlock:block];
    YapDatabaseFullTextSearch *fts = [[YapDatabaseFullTextSearch alloc] initWithColumnNames:@[@"fullText"] handler:handler];
    [self.database registerExtension:fts withName:@"fts"];
}

- (NSString *)keyForSessionWithYear:(NSNumber *)year id:(NSNumber *)sessionId
{
    return [NSString stringWithFormat:@"%@-%@", year, sessionId];
}

- (BOOL)indexMatches:(NSArray *)sessions
{
    __block NSUInteger count = 0;
    [self.connection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
        count = [transaction numberOfKeysInCollection:kCollectionName];
    }];
    
    return (count == sessions.count);
}

- (void)indexTranscriptForYear:(NSNumber *)year session:(NSNumber *)sessionId
{
    [self.connection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
        NSString *key = [self keyForSessionWithYear:year id:sessionId];
        id indexedTranscript = [transaction objectForKey:[self keyForSessionWithYear:year id:sessionId] inCollection:kCollectionName];
        if (!indexedTranscript) {
            [self doIndexTranscriptForYear:year session:sessionId];
        } else {
            #ifdef DEBUG_INDEXING
            NSLog(@"[ASCIIWWDCTranscriptIndexer] Index for session %@ already exists, skipping", key);
            #endif
            self.transcriptsToProcess--;
        }
    }];
}

- (void)doIndexTranscriptForYear:(NSNumber *)year session:(NSNumber *)sessionId
{
    #ifdef DEBUG_INDEXING
    NSLog(@"[ASCIIWWDCTranscriptIndexer] Indexing transcript for session %@-%@", year, sessionId);
    #endif
    
    [[ASCIIWWDCClient sharedClient] fetchTranscriptForYear:year.intValue session:sessionId.intValue completionHandler:^(BOOL success, WWDCSessionTranscript *transcript) {
        [self.connection readWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
            NSString *key = [NSString stringWithFormat:@"%@-%@", year, sessionId];
        
            if (!success) {
                [transaction setObject:[NSNull null] forKey:key inCollection:kCollectionName];
            } else {
                [transaction setObject:transcript forKey:key inCollection:kCollectionName];
                #ifdef DEBUG_INDEXING
                NSLog(@"[ASCIIWWDCTranscriptIndexer] Successfully indexed transcript for session %@-%@", year, sessionId);
                #endif
            }
            
            self.processedTranscripts++;
            [self checkForCompletionIgnoringStats:NO];
        }];
    }];
}

- (void)checkForCompletionIgnoringStats:(BOOL)ignoreStats
{
    if (!self.indexCompletionHandler) return;
    
    if (self.processedTranscripts == self.transcriptsToProcess || ignoreStats) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.indexCompletionHandler();
        });
    }
}

@end
