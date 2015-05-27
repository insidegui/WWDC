//
//  ASCIIWWDCClient.m
//  ASCIIwwdc
//
//  Created by Guilherme Rambo on 23/04/15.
//  Copyright (c) 2015 Guilherme Rambo. All rights reserved.
//

#import "ASCIIWWDCClient.h"

#import "WWDCSessionTranscript.h"
#import "WWDCTranscriptLine.h"

#define kASCIIWWDCServiceURLFormat @"http://asciiwwdc.com/%d/sessions/%d"

@interface ASCIIWWDCClient ()

@property (strong) NSURLSession *urlSession;

@end

@implementation ASCIIWWDCClient

#pragma mark Public API

+ (ASCIIWWDCClient *)sharedClient
{
    static ASCIIWWDCClient *_instance;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [[ASCIIWWDCClient alloc] init];
    });
    
    return _instance;
}

- (void)fetchTranscriptForYear:(int)year session:(int)session completionHandler:(void (^)(BOOL success, WWDCSessionTranscript *transcript))callback
{
    [[self.urlSession dataTaskWithRequest:[self requestForYear:year session:session] completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            callback(NO, nil);
            return;
        }
        
        NSError *jsonSerializationError;
        NSDictionary *transcriptInfo = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonSerializationError];
        if (jsonSerializationError) {
            callback(NO, nil);
            return;
        }
        
        NSArray *annotations = transcriptInfo[@"annotations"];
        NSArray *timecodes = transcriptInfo[@"timecodes"];
        
        // For transcripts that are unavailable objects for keys annotations, timecodes are nil values represented using NSNull. Causing the app to crash when lines mutable array is initialized with null object count
        if ([annotations isKindOfClass:[NSNull class]] || [timecodes isKindOfClass:[NSNull class]]) {
            callback(NO, nil);
            return;
        }
        
        NSMutableArray *lines = [[NSMutableArray alloc] initWithCapacity:annotations.count];
        
        for (NSString *annotation in annotations) {
            WWDCTranscriptLine *line = [[WWDCTranscriptLine alloc] init];
            line.text = annotation;
            line.timecode = [[timecodes objectAtIndex:[annotations indexOfObject:annotation]] doubleValue];
            [lines addObject:line];
        }
        
        WWDCSessionTranscript *transcript = [[WWDCSessionTranscript alloc] init];
        transcript.year = year;
        transcript.session = session;
        transcript.lines = [lines copy];
        
        callback(YES, transcript);
    }] resume];
}

#pragma mark Private API

- (instancetype)init
{
    if (!(self = [super init])) return nil;
    
    self.urlSession = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
    
    return self;
}

- (NSURLRequest *)requestForYear:(int)year session:(int)session
{
    NSString *serviceURL = [NSString stringWithFormat:kASCIIWWDCServiceURLFormat, year, session];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:serviceURL]];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    
    return [request copy];
}

@end
