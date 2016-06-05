//
//  UDUpdater.m
//  Updater
//
//  Created by Guilherme Rambo on 01/05/15.
//  Copyright (c) 2015 Guilherme Rambo. All rights reserved.
//

#import "UDUpdater.h"
#import "UDRelease.h"

#define kGithubAPIEndpoint @"https://api.github.com/"
#define kRepoCreatorKey @"UDRepoCreator"
#define kRepoNameKey @"UDRepoName"

@interface UDUpdater ()

@property (strong) NSURLSession *session;

@property (readonly) NSString *repoCreator;
@property (readonly) NSString *repoName;
@property (readonly) NSURL *releasesURL;

@property (readonly) NSString *releaseFilenamePrefix;
@property (readonly) NSString *localStoragePath;

@end

@implementation UDUpdater

+ (UDUpdater *)sharedUpdater
{
    static UDUpdater *_updater;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _updater = [[UDUpdater alloc] init];
    });
    
    return _updater;
}

- (void)checkForUpdatesWithCompletionHandler:(void (^)(UDRelease *latestRelease))callback
{
    if ([[NSProcessInfo processInfo].arguments containsObject:@"disable-updates"]) {
        #ifdef DEBUG
        NSLog(@"Updater: disable-updates argument is present, automatic updates disabled");
        #endif
        return;
    }
    
    [[self.session dataTaskWithURL:self.releasesURL completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            #ifdef DEBUG
            NSLog(@"Updater failed to get updates from %@. Error: %@", self.releasesURL, error);
            #endif
            dispatch_async(dispatch_get_main_queue(), ^{
                callback(nil);
            });
            return;
        }
        
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        if (httpResponse.statusCode > 400) {
            #ifdef DEBUG
            NSLog(@"Updater failed to get updates from %@. Status code: %ld", self.releasesURL, (long)httpResponse.statusCode);
            #endif
            dispatch_async(dispatch_get_main_queue(), ^{
                callback(nil);
            });
            return;
        }
        
        NSError *jsonError;
        NSArray *releases = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&jsonError];
        if (jsonError) {
            #ifdef DEBUG
            NSLog(@"Updater failed to process JSON data from %@. Error: %@", self.releasesURL, jsonError);
            #endif
            dispatch_async(dispatch_get_main_queue(), ^{
                callback(nil);
            });
            return;
        }
        
        UDRelease *latestRelease = [UDRelease releaseWithDictionaryRepresentation:releases[0]];
        #ifdef DEBUG
        NSLog(@"Latest release available is %@", latestRelease.version);
        #endif
        
        if (latestRelease.prerelease || latestRelease.draft || latestRelease.download == nil || [latestRelease.download isEqualToString:@""]) {
            #ifdef DEBUG
            NSLog(@"Latest release is prerelease, draft or empty. Ignoring...");
            #endif
            return;
        }
        
        if ([latestRelease isGreaterThan:[NSApplication sharedApplication].ud_currentRelease]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                callback(latestRelease);
            });
            if (self.updateAutomatically) [self downloadAndInstallRelease:latestRelease completionHandler:nil];
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                callback(nil);
            });
        }
    }] resume];
}

- (void)downloadAndInstallRelease:(UDRelease *)release completionHandler:(void (^)(BOOL))callback
{
    [[self.session downloadTaskWithURL:release.downloadURL completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error) {
        if (error) {
            #ifdef DEBUG
            NSLog(@"Updater failed to download release %@ from %@", release.version, release.downloadURL);
            #endif
            dispatch_async(dispatch_get_main_queue(), ^{
                if (callback) callback(NO);
            });
            return;
        }
        
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        if (httpResponse.statusCode > 400) {
            #ifdef DEBUG
            NSLog(@"Updater failed to download release from %@. Status code: %ld", self.releasesURL, (long)httpResponse.statusCode);
            #endif
            dispatch_async(dispatch_get_main_queue(), ^{
                if (callback) callback(NO);
            });
            return;
        }
        
        NSString *path = [self.localStoragePath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@%@_%d.zip", self.releaseFilenamePrefix, release.version, release.identifier]];
        NSError *moveError;
        [[NSFileManager defaultManager] moveItemAtPath:location.path toPath:path error:&moveError];
        
        if (moveError) {
            #ifdef DEBUG
            NSLog(@"Updater failed to move downloaded release from %@ to %@", location.path, path);
            #endif
            dispatch_async(dispatch_get_main_queue(), ^{
                if (callback) callback(NO);
            });
            return;
        } else {
            #ifdef DEBUG
            NSLog(@"New release downloaded and moved from %@ to %@", location.path, path);
            #endif
            
            [self installRelease:release fromFileAtPath:path completionHandler:callback];
        }
        
    }] resume];
}

#pragma mark Private API

- (instancetype)init
{
    if (!(self = [super init])) return nil;
    
    self.session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];

    return self;
}

- (NSString *)repoCreator
{
    NSDictionary *dict = [[NSBundle mainBundle] infoDictionary];
    
    return dict[kRepoCreatorKey];
}

- (NSString *)repoName
{
    NSDictionary *dict = [[NSBundle mainBundle] infoDictionary];
    
    return dict[kRepoNameKey];
}

- (NSURL *)releasesURL
{
    NSString *path = [NSString pathWithComponents:@[@"repos", self.repoCreator, self.repoName, @"releases"]];
    NSString *urlString = [kGithubAPIEndpoint stringByAppendingPathComponent:path];
    
    return [NSURL URLWithString:urlString];
}

- (NSString *)localStoragePath
{
    NSString *cacheDir = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
    NSString *path = [cacheDir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@temp%d", self.releaseFilenamePrefix, [NSProcessInfo processInfo].processIdentifier]];

    if (![[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:NULL]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:NO attributes:nil error:NULL];
    }
    
    return path;
}

- (NSString *)releaseFilenamePrefix
{
    return [NSString stringWithFormat:@"%@_update_", [NSProcessInfo processInfo].processName];
}

- (void)installRelease:(UDRelease *)release fromFileAtPath:(NSString *)path completionHandler:(void(^)(BOOL success))callback
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        NSTask *unzipTask = [[NSTask alloc] init];
        unzipTask.launchPath = @"/usr/bin/unzip";
        unzipTask.currentDirectoryPath = path.stringByDeletingLastPathComponent;
        unzipTask.arguments = @[path];
        unzipTask.standardError = [NSPipe pipe];
        unzipTask.standardOutput = [NSPipe pipe];
        [unzipTask launch];
        [unzipTask waitUntilExit];
        
        // check unzip result
        if (unzipTask.terminationStatus != 0) {
            #ifdef DEBUG
            NSLog(@"Failed to unzip %@", path);
            #endif
            dispatch_async(dispatch_get_main_queue(), ^{
                if (callback) callback(NO);
            });
            return;
        }
        
        // current running app's path
        NSString *currentAppPath = [NSBundle mainBundle].bundlePath;
        // downloaded and unzipped app's path
        NSString *newAppPath = [self.localStoragePath stringByAppendingPathComponent:currentAppPath.lastPathComponent];
        
        // swap current app with the downloaded app
        NSError *deleteError;
        if ([[NSFileManager defaultManager] removeItemAtPath:currentAppPath error:&deleteError]) {
            NSError *moveError;
            if ([[NSFileManager defaultManager] moveItemAtPath:newAppPath toPath:currentAppPath error:&moveError]) {
                
                // delete temporary directory
                [[NSFileManager defaultManager] removeItemAtPath:self.localStoragePath error:nil];
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (callback) callback(YES);
                });
                
            } else {
                #ifdef DEBUG
                NSLog(@"Error installing new app version %@", moveError);
                #endif
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (callback) callback(NO);
                });
            }
        } else {
            #ifdef DEBUG
            NSLog(@"Error removing current app version %@", deleteError);
            #endif
            dispatch_async(dispatch_get_main_queue(), ^{
                if (callback) callback(NO);
            });
        }
    });
}

@end
