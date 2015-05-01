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

@interface ASCIIWWDCClient ()

@property (strong) NSURLSession *urlSession;
@property (nonatomic, strong) NSURL *baseURL;

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

- (void)fetchTranscriptForYear:(NSInteger)year
					 sessionID:(NSInteger)sessionID
			 completionHandler:(ASCIIWWDCClientCallback)callback
{
	NSURLComponents *URLComps = [self URLComponents];
	URLComps.path = [NSString stringWithFormat:@"/%ld/sessions/%ld", (long)year, (long)sessionID];
	NSURLRequest *request = [NSURLRequest requestWithURL:[URLComps URL]];
	[[self.urlSession dataTaskWithRequest:request
						completionHandler:
	  ^(NSData *data, NSURLResponse *response, NSError *error) {
		  if (error) {
			  callback(NO, nil);
			  return;
		  }
		  
		  NSError *jsonSerializationError;
		  NSDictionary *transcriptInfo = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonSerializationError];
		  if (jsonSerializationError) {
			  callback(NO, nil);
		  }
		  
		  NSArray *annotations = transcriptInfo[@"annotations"];
		  NSArray *timecodes = transcriptInfo[@"timecodes"];
		  NSMutableArray *lines = [[NSMutableArray alloc] initWithCapacity:annotations.count];
		  
		  for (NSString *annotation in annotations) {
			  WWDCTranscriptLine *line = [[WWDCTranscriptLine alloc] init];
			  line.text = annotation;
			  line.timecode = [[timecodes objectAtIndex:[annotations indexOfObject:annotation]] doubleValue];
			  [lines addObject:line];
		  }
		  
		  WWDCSessionTranscript *transcript = [[WWDCSessionTranscript alloc] init];
		  transcript.year = year;
		  transcript.sessionID = sessionID;
		  transcript.lines = [lines copy];
		  
		  callback(YES, transcript);
	  }] resume];
}

- (void)fetchTranscriptsForQuery:(NSString *)query
			   completionHandler:(ASCIIWWDCClientArrayCallback)callback
{
	NSURLComponents *URLComps = [self URLComponents];
	URLComps.queryItems = [self URLQueryWithParams:@{ @"q" : query }];
	URLComps.path = @"/search";
	NSURLRequest *request = [NSURLRequest requestWithURL:[URLComps URL]];
	[[self.urlSession dataTaskWithRequest:request
						completionHandler:
	  ^(NSData *data, NSURLResponse *response, NSError *error) {
		  if (error) {
			  callback(NO, nil);
			  return;
		  }
		  NSError *jsonSerializationError;
		  NSDictionary *transcriptInfo = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonSerializationError];
		  if (jsonSerializationError) {
			  callback(NO, nil);
		  }
		  NSArray *results = transcriptInfo[@"results"];
		  NSMutableArray *retVal = [NSMutableArray new];
		  [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
			  NSDictionary *transDic = obj;
			  WWDCSessionTranscript *transcript = [[WWDCSessionTranscript alloc] init];
			  transcript.year = [transDic[@"year"] intValue];
			  transcript.sessionID = [transDic[@"number"] intValue];
			  [retVal addObject:transcript];
		  }];
		  callback(YES, retVal);
	  }] resume];
}

#pragma mark Private API

- (instancetype)init
{
	if (!(self = [super init])) return nil;
	
	self.baseURL = [NSURL URLWithString:@"http://asciiwwdc.com"];
	NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
	configuration.HTTPAdditionalHeaders = @{ @"Accept" : @"application/json" };
	self.urlSession = [NSURLSession sessionWithConfiguration:configuration];
	
	return self;
}

- (NSURLComponents *)URLComponents {
	NSURL *endpointURL = self.baseURL;
	NSURLComponents *comps = [NSURLComponents componentsWithURL:endpointURL resolvingAgainstBaseURL:NO];
	return comps;
}

- (NSArray *)URLQueryWithParams:(NSDictionary *)paramsDic {
	NSMutableArray *retVal = [NSMutableArray new];
	[paramsDic enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
		if ([obj isKindOfClass:[NSString class]] &&
			[key isKindOfClass:[NSString class]])
		{
			NSURLQueryItem *item = [[NSURLQueryItem alloc] initWithName:key value:obj];
			[retVal addObject:item];
		}
	}];
	return [retVal copy];
}

@end
