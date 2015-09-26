//
//  GRPlayerWindow.m
//
//  Created by Guilherme Rambo on 15/12/14.
//  Copyright (c) 2014 Guilherme Rambo. All rights reserved.
//

#import "GRPlayerWindow.h"

#import <objc/runtime.h>

#ifdef DEBUG
@interface FScriptMenuItem: NSObject
+ (void)insertInMainMenu;
@end
#endif

@interface GRPlayerWindowFrame : NSView
+ (void)installPlayerWindowTitleTextSwizzles;
@end

@interface GRPlayerWindowFrame (Swizzles)
- (NSBackgroundStyle)_NS_backgroundStyleForTitleTextField;
- (NSColor *)_NS_currentTitleColor;
@end

@implementation GRPlayerWindow

+ (void)load
{
    [GRPlayerWindowFrame installPlayerWindowTitleTextSwizzles];
}

- (void)makeKeyAndOrderFront:(id)sender
{
    [super makeKeyAndOrderFront:sender];
    
    #ifdef DEBUG
    if ([[NSBundle bundleWithPath:@"/Library/Frameworks/FScript.framework"] load]) {
        [NSClassFromString(@"FScriptMenuItem") performSelector:@selector(insertInMainMenu)];
    }
    #endif
    
    [self configureTitlebar];
}

- (void)configureTitlebar
{
    self.titlebarView.material = NSVisualEffectMaterialDark;
    self.titlebarView.state = NSVisualEffectStateActive;
}

- (void)sizeToFitVideoSize:(NSSize)videoSize ignoringScreenSize:(BOOL)ignoreScreen animated:(BOOL)animate
{
    CGFloat wRatio, hRatio, resizeRatio;
    NSRect screenRect = [NSScreen mainScreen].frame;
    NSSize screenSize = screenRect.size;
    
    if (videoSize.width >= videoSize.height) {
        wRatio = screenSize.width / videoSize.width;
        hRatio = screenSize.height / videoSize.height;
    } else {
        wRatio = screenSize.height / videoSize.width;
        hRatio = screenSize.width / videoSize.height;
    }
    
    resizeRatio = MIN(wRatio, hRatio);
    
    NSSize newSize = NSMakeSize(videoSize.width*resizeRatio, videoSize.height*resizeRatio);
    
    if (ignoreScreen) {
        newSize.width = videoSize.width;
        newSize.height = videoSize.height;
    }
    
    NSRect newRect = NSMakeRect(screenSize.width/2-newSize.width/2, screenSize.height/2-newSize.height/2, newSize.width, newSize.height);

    [self setFrame:newRect display:YES animate:animate];
    
    if (!animate) [self center];
}

@end

@implementation GRPlayerWindowFrame

+ (void)installPlayerWindowTitleTextSwizzles
{
    Class targetClass = NSClassFromString(@"NSThemeFrame");
    NSArray *methodsToOverride = @[@"_backgroundStyleForTitleTextField", @"_currentTitleColor"];
    for (NSString *selector in methodsToOverride) {
        Method m1 = class_getInstanceMethod(targetClass, NSSelectorFromString(selector));
        Method m2 = class_getInstanceMethod([self class], NSSelectorFromString([selector stringByReplacingOccurrencesOfString:@"_" withString:@"_GR_"]));
        class_addMethod(targetClass, NSSelectorFromString([selector stringByReplacingOccurrencesOfString:@"_" withString:@"_NS_"]), method_getImplementation(m1), method_getTypeEncoding(m1));
        method_exchangeImplementations(m1, m2);
    }
}

- (NSBackgroundStyle)_GR_backgroundStyleForTitleTextField
{
    if ([self.window isKindOfClass:[GRPlayerWindow class]]) {
        return NSBackgroundStyleDark;
    } else {
        return [self _NS_backgroundStyleForTitleTextField];
    }
}

- (NSColor *)_GR_currentTitleColor
{
    if ([self.window isKindOfClass:[GRPlayerWindow class]]) {
        return [NSColor secondaryLabelColor];
    } else {
        return [self _NS_currentTitleColor];
    }
}

@end