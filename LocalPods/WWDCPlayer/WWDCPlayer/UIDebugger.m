//
//  UIDebugger.m
//  UIDebugger
//
//  Created by Guilherme Rambo on 25/03/16.
//  Copyright © 2016 Guilherme Rambo. All rights reserved.
//

#import "UIDebugger.h"

@interface UIDebuggerMenuItem: NSMenuItem
+ (void)insertInMainMenu;
@end

@implementation UIDebugger

#ifdef DEBUG

+ (void)load
{
    [[NSNotificationCenter defaultCenter] addObserverForName:NSApplicationDidFinishLaunchingNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification * _Nonnull note) {
        [UIDebuggerMenuItem insertInMainMenu];
        
        if ([[NSBundle bundleWithPath:@"/Library/Frameworks/FScript.framework"] load]) {
            NSLog(@"[UIDebugger] Successfully added FScript menu");
            
            [NSApp sendAction:NSSelectorFromString(@"insertInMainMenu") to:NSClassFromString(@"FScriptMenuItem") from:nil];
        } else {
            NSLog(@"[UIDebugger] FScript.framework could not be loaded");
        }
    }];
}

#endif

@end

@implementation UIDebuggerMenuItem

#ifdef DEBUG

+ (void)insertInMainMenu
{
    [[[NSApplication sharedApplication] mainMenu] addItem:[[self alloc] init]];
}


- (id)init
{
    return [self initWithTitle:@"Debug UI" action:@selector(submenuAction:) keyEquivalent:@""];
}

- (id)initWithTitle:(NSString *)itemName action:(SEL)anAction keyEquivalent:(NSString *)charCode
{
    if (self = [super initWithTitle:itemName action:anAction keyEquivalent:charCode])
    {
        NSMenu *submenu = [[NSMenu alloc] initWithTitle:@"Debug UI"];
        
        NSMenuItem *item1 = [[NSMenuItem alloc] initWithTitle:@"Visualize Constraints" action:@selector(visualizeConstraints:) keyEquivalent:@""];
        [item1 setTarget:self];
        [submenu addItem:item1];
        
        [self setSubmenu:submenu];
        
        return self;
    }
    return nil;
}

- (IBAction)visualizeConstraints:(id)sender
{
    NSWindow *window = [NSApp mainWindow];
    NSView *firstResponderView = (NSView *)window.firstResponder;
    
    if ([firstResponderView respondsToSelector:@selector(constraints)]) {
        [window visualizeConstraints:firstResponderView.constraints];
    } else {
        [window visualizeConstraints:window.contentView.constraints];
    }
}

#endif

@end