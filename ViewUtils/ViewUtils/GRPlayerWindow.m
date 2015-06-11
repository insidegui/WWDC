//
//  GRPlayerWindow.m
//
//  Created by Guilherme Rambo on 15/12/14.
//  Copyright (c) 2014 Guilherme Rambo. All rights reserved.
//

#import "GRPlayerWindow.h"

#ifdef DEBUG
@interface FScriptMenuItem: NSObject
+ (void)insertInMainMenu;
@end
#endif

@implementation GRPlayerWindow

- (void)makeKeyAndOrderFront:(id)sender
{
    [super makeKeyAndOrderFront:sender];
    
    #ifdef DEBUG
    if ([[NSBundle bundleWithPath:@"/Library/Frameworks/FScript.framework"] load]) {
        [NSClassFromString(@"FScriptMenuItem") performSelector:@selector(insertInMainMenu)];
    }
    #endif
    
    [self _gr_customizeTitleIfNeeded];
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

// On El Capitan and up (>=10.11), we need to customize the titlebar label color
- (void)_gr_customizeTitleIfNeeded
{
    NSOperatingSystemVersion v = [NSProcessInfo processInfo].operatingSystemVersion;
    if (v.majorVersion != 10 || v.minorVersion < 11) return;
    
    NSTextField *label = [self titlebarTextField];
    label.textColor = [NSColor tertiaryLabelColor];
    label.shadow = nil;
    [label.cell setBackgroundStyle:NSBackgroundStyleDark];
}

- (NSTextField *)titlebarTextField
{
    for (id subview in self.titlebarView.subviews) {
        if ([subview isKindOfClass:[NSTextField class]]) return subview;
    }
    
    return nil;
}

@end