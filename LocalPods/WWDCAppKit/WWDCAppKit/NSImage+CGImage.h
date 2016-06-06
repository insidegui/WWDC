//
//  NSImage+CGImage.h
//  GRProKit2
//
//  Created by Guilherme Rambo on 21/09/15.
//  Copyright © 2015 Guilherme Rambo. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface NSImage (CGImage)

@property (nonatomic, readonly) CGImageRef CGImage;

@end
