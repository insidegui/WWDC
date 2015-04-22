//
//  NSString+AttributedSearch.h
//  AttributedSearchFiltering
//
//  Created by Jesús on 22/4/15.
//  Copyright (c) 2015 Jesús. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (QualifierSearchParser)

/*
 This method parses the given string and creates a Dictionary extracting the values for the qualifiers
 found in it.
 The returned dictionary will contain a value for each qualifier and an special key "_query" for the
 non qualifier text in the queryString.
 */
- (NSDictionary*)qualifierSearchParser_parseQualifiers:(NSArray*)queryParameters;

@end
