//
//  XPCConnectionValidator.h
//  WWDCAgent
//
//  Created by Guilherme Rambo on 02/04/20.
//  Copyright © 2020 Guilherme Rambo. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface XPCConnectionValidator : NSObject

- (instancetype __nullable)initWithRequirements:(NSString *)requirements;
- (BOOL)validateConnection:(NSXPCConnection *)connection;
- (BOOL)validateSignatureOfBinaryAtPath:(NSString *)path;

@end

NS_ASSUME_NONNULL_END
