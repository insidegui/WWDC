//
//  XPCConnectionValidator.m
//  WWDCAgent
//
//  Created by Guilherme Rambo on 02/04/20.
//  Copyright © 2020 Guilherme Rambo. All rights reserved.
//

#import "XPCConnectionValidator.h"

@import Security;
@import os.log;

@interface NSXPCConnection (Private)

@property (readonly) audit_token_t auditToken;

@end

@interface XPCConnectionValidator ()

@property (strong) os_log_t log;
@property (assign) SecRequirementRef requirements;

@end

@implementation XPCConnectionValidator

- (instancetype)initWithRequirements:(NSString *)requirements
{
    self = [super init];
    if (!self) return nil;

    self.log = os_log_create("io.wwdc.app.Agent", "XPCConnectionValidator");

    SecRequirementRef req = NULL;

    if (SecRequirementCreateWithString((__bridge CFStringRef)requirements, kSecCSDefaultFlags, &req) != noErr) {
        os_log_fault(self.log, "Unable to compile code requirements from string: %@", requirements);
        NSAssert(false, @"Unable to compile code requirements");
        return nil;
    }

    self.requirements = req;

    return self;
}

- (BOOL)validateConnection:(NSXPCConnection *)connection
{
    os_log_debug(self.log, "%{public}@ %@", NSStringFromSelector(_cmd), connection);

    audit_token_t token = connection.auditToken;
    NSData *tokenData = [NSData dataWithBytes:&token length:sizeof(audit_token_t)];

    NSDictionary *attrs = @{(__bridge NSString *)kSecGuestAttributeAudit: tokenData};
    SecCodeRef client;
    OSStatus err = SecCodeCopyGuestWithAttributes(NULL, (__bridge CFDictionaryRef)(attrs), kSecCSDefaultFlags, &client);
    if (err != noErr) {
        NSString *message = (__bridge NSString *)SecCopyErrorMessageString(err, NULL);
        os_log_fault(self.log, "Failed to copy client cs attributes. Error code: %{public}d. Message: %{public}@", err, message);
        return NO;
    }

    CFErrorRef validityErrors;
    if (SecCodeCheckValidityWithErrors(client, kSecCSDefaultFlags, self.requirements, &validityErrors) != noErr) {
        os_log_error(self.log, "Client signature didn't meet requirements, denying connection");
        return NO;
    }

    return YES;
}

- (BOOL)validateSignatureOfBinaryAtPath:(NSString *)path
{
    os_log_debug(self.log, "%{public}@ %@", NSStringFromSelector(_cmd), path);

    CFURLRef url = (__bridge CFURLRef)[NSURL fileURLWithPath:path];

    SecStaticCodeRef staticCode;

    if (SecStaticCodeCreateWithPath(url, kSecCSDefaultFlags, &staticCode) != noErr) {
        os_log_fault(self.log, "Failed to copy client cs attributes");
        return NO;
    }

    CFErrorRef validityErrors;
    if (SecStaticCodeCheckValidityWithErrors(staticCode, kSecCSDefaultFlags, self.requirements, &validityErrors) != noErr) {
        os_log_error(self.log, "Client signature didn't meet requirements, denying connection");
        return NO;
    }

    return YES;
}

@end
