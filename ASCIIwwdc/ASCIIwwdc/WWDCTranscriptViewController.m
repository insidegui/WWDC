//
//  WWDCTranscriptViewController.m
//  ASCIIwwdc
//
//  Created by Guilherme Rambo on 23/04/15.
//  Copyright (c) 2015 Guilherme Rambo. All rights reserved.
//

#import "WWDCTranscriptViewController.h"

#import "ASCIIWWDCClient.h"
#import "WWDCSessionTranscript.h"
#import "WWDCTranscriptLine.h"
#import "WWDCTranscriptWebUtils.h"

#import "NSColor+CSS.h"

@import WebKit;

@interface WWDCTranscriptViewController () <WebFrameLoadDelegate>

@property (weak) IBOutlet WebView *webView;
@property (weak) IBOutlet NSProgressIndicator *progressIndicator;
@property (weak) IBOutlet NSTextField *errorLabel;
@property (weak) IBOutlet NSButton *autoscrollingCheckbox;
@property (weak) IBOutlet NSVisualEffectView *bottomBarView;
@property (weak) IBOutlet NSSearchField *searchField;

@end

@implementation WWDCTranscriptViewController

#pragma mark Public API

+ (WWDCTranscriptViewController *)transcriptViewControllerWithYear:(int)year session:(int)session
{
    Class viewControllerClass = [WWDCTranscriptViewController class];
    NSBundle *bundle = [NSBundle bundleForClass:viewControllerClass];
    WWDCTranscriptViewController *instance = [[WWDCTranscriptViewController alloc] initWithNibName:NSStringFromClass(viewControllerClass) bundle:bundle];
    
    instance.year = year;
    instance.session = session;
    
    return instance;
}

- (void)highlightLineAt:(NSString *)roundedTimecode
{
    NSString *script = [NSString stringWithFormat:@"highlightLineWithTimecode('%@')", roundedTimecode];
    
    [self.webView.windowScriptObject evaluateWebScript:script];
}

- (void)searchFor:(NSString *)term
{
    NSString *script = [NSString stringWithFormat:@"filterLinesByTerm('%@')", term];
    
    [self.webView.windowScriptObject evaluateWebScript:script];
}

#pragma mark Private API

#define kAutoscrollingEnabledKey @"Autoscrolling Enabled"

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.searchField.enabled = NO;
    
    [self.webView setFrameLoadDelegate:self];
    
    [self.progressIndicator startAnimation:nil];
    
    [[ASCIIWWDCClient sharedClient] fetchTranscriptForYear:self.year session:self.session completionHandler:^(BOOL success, WWDCSessionTranscript *transcript) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.progressIndicator stopAnimation:nil];
            
            if (!success) {
                [self.errorLabel setHidden:NO];
                return;
            }
            
            [self.webView.mainFrame loadHTMLString:transcript.htmlString baseURL:[WWDCTranscriptWebUtils baseURL]];
            
            if (self.transcriptAvailableCallback) self.transcriptAvailableCallback(transcript);
        });
    }];
}

- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame
{
    [self.webView.windowScriptObject setValue:self forKey:@"controller"];
    
    [self setAutoscrollingEnabled:(self.autoscrollingCheckbox.state == NSOnState)];
    self.searchField.enabled = YES;
    
    [self updateWebviewLook];
}

+ (BOOL)isSelectorExcludedFromWebScript:(SEL)aSelector
{
    return NO;
}

+ (NSString *)webScriptNameForSelector:(SEL)selector
{
    if (selector == @selector(jumpToTimecode:)) {
        return @"jumpToTimecode";
    }
    if (selector == @selector(jsLog:)) {
        return @"jsLog";
    }
    
    return nil;
}

- (void)jsLog:(NSString *)message
{
    #ifdef DEBUG
    NSLog(@"[JSLOG] %@", message);
    #endif
}

- (void)jumpToTimecode:(id)timecode
{
    if (self.jumpToTimecodeCallback) self.jumpToTimecodeCallback([timecode doubleValue]);
    
    [self highlightLineAt:[WWDCTranscriptLine roundedStringFromTimecode:[timecode doubleValue]]];
}

- (IBAction)enableAutoscrollingAction:(id)sender {
    if (self.autoscrollingCheckbox.state == NSOnState) {
        [self setAutoscrollingEnabled:YES];
    } else {
        [self setAutoscrollingEnabled:NO];
    }
}

- (void)setAutoscrollingEnabled:(BOOL)enabled
{
    if (enabled) {
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:kAutoscrollingEnabledKey];
        [self.webView.windowScriptObject evaluateWebScript:@"setAutoScrollEnabled(true)"];
        self.autoscrollingCheckbox.state = NSOnState;
    } else {
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:kAutoscrollingEnabledKey];
        [self.webView.windowScriptObject evaluateWebScript:@"setAutoScrollEnabled(false)"];
        self.autoscrollingCheckbox.state = NSOffState;
    }
}

- (IBAction)searchFieldAction:(id)sender {
    if ([self.searchField.stringValue isEqualToString:@""] || !self.searchField.stringValue) {
        [self setAutoscrollingEnabled:YES];
    } else {
        [self setAutoscrollingEnabled:NO];
    }
    [self searchFor:self.searchField.stringValue];
}

- (void)setFont:(NSFont *)font
{
    _font = [font copy];
    
    [self updateWebviewLook];
}

- (void)setTextColor:(NSColor *)textColor
{
    _textColor = [textColor copy];
    
    [self updateWebviewLook];
}

- (void)setBackgroundColor:(NSColor *)backgroundColor
{
    _backgroundColor = [backgroundColor copy];
    
    [self updateWebviewLook];
}

- (void)updateWebviewLook
{
    NSMutableString *script = [NSMutableString new];
    [script appendFormat:@"setFontSize(%.0f);\n", self.font.pointSize];
    [script appendFormat:@"setFontName(\"%@\");", self.font.familyName];
    [script appendFormat:@"setTextColor(\"%@\");", [self.textColor cssColor]];
    [script appendFormat:@"setBackgroundColor(\"%@\");", [self.backgroundColor cssColor]];
    
    [self.webView.windowScriptObject evaluateWebScript:script];
}

@end
