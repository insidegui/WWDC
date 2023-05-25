/**
 https://github.com/insidegui/VisualEffectDebugger
 
 © 2022 Guilherme Rambo – BSD-2 license
 
 Simple debugger for `NSVisualEffectView`.
 
 Just drop `VisualEffectDebugger.m` into your Xcode project and add `-AUIEnableVisualEffectDebugger YES` to your scheme's
 "Arguments Passed on Launch" (or run `defaults write com.your.bundle.id AUIEnableVisualEffectDebugger YES` in Terminal).
 
 When it's enabled, right-clicking any visual effect view in the app will show a menu where you can
 toggle between the different materials.
 
 If multiple visual effect views are overlapping, you can use the keyboard shortcut
 Control + Option + Command + X with the cursor on top of the views to see a menu that
 displays each visual effect view below the cursor and highlights the given view when
 you hover over the menu item corresponding to that view.
 
 Disclaimer:
 Made real quick just to accelerate my workflow while developing some UI stuff in my app.
 Only tested in macOS Monterey 12.2, but should work in previous versions. There are definitely bugs.
 Also please do not ship this in your app, that's why the whole code is within `#if DEBUG` / `#endif`.
 */

#if DEBUG

@import Cocoa;
@import ObjectiveC.runtime;

@interface VisualEffectDebugger : NSObject

@end

@interface NSVisualEffectView (GRDebuggerRuntime)

- (void)__gr_original_viewDidMoveToWindow;
- (void)__gr_cycleMaterials;

@end

@interface __VisualEffectDebuggerVFXView: NSVisualEffectView

+ (NSString *)nameForMaterial:(NSVisualEffectMaterial)material;

- (void)__gr_didMoveToWindow;
- (void)__gr_updateMaterialsMenu;
- (void)__gr_handleSelectedMaterialItem:(NSMenuItem *)sender;

@end

@interface VisualEffectDebugger () <NSMenuDelegate>

@property (nonatomic, strong) id eventMonitor;
@property (nonatomic, strong) NSMenu *viewPicker;
@property (nonatomic, strong) NSPanel *selectionWindow;

@end

#define kSelectionWindowTitle @"____VisualEffectDebuggerSelection"

@implementation VisualEffectDebugger

+ (instancetype)sharedDebugger
{
    static dispatch_once_t onceToken;
    static VisualEffectDebugger *_debugger;
    dispatch_once(&onceToken, ^{
        _debugger = [VisualEffectDebugger new];
    });
    return _debugger;
}

+ (BOOL)isEnabled
{
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"AUIEnableVisualEffectDebugger"];
}

+ (void)load
{
    if (![self isEnabled]) return;
    
    Method m = class_getInstanceMethod([NSVisualEffectView class], @selector(viewDidMoveToWindow));
    Method m2 = class_getInstanceMethod([__VisualEffectDebuggerVFXView class], @selector(__gr_didMoveToWindow));
    class_addMethod([NSVisualEffectView class], @selector(__gr_original_viewDidMoveToWindow), method_getImplementation(m), method_getTypeEncoding(m));
    method_exchangeImplementations(m, m2);

    Method handleMaterialSelected = class_getInstanceMethod([__VisualEffectDebuggerVFXView self], @selector(__gr_handleSelectedMaterialItem:));
    class_addMethod([NSVisualEffectView class], @selector(__gr_handleSelectedMaterialItem:), method_getImplementation(handleMaterialSelected), method_getTypeEncoding(handleMaterialSelected));
    
    Method updateMaterialsMenu = class_getInstanceMethod([__VisualEffectDebuggerVFXView self], @selector(__gr_updateMaterialsMenu));
    class_addMethod([NSVisualEffectView class], @selector(__gr_updateMaterialsMenu), method_getImplementation(updateMaterialsMenu), method_getTypeEncoding(updateMaterialsMenu));
    
    Method cycleMaterials = class_getInstanceMethod([__VisualEffectDebuggerVFXView self], @selector(__gr_cycleMaterials));
    class_addMethod([NSVisualEffectView class], @selector(__gr_cycleMaterials), method_getImplementation(cycleMaterials), method_getTypeEncoding(cycleMaterials));
    
    [[NSNotificationCenter defaultCenter] addObserverForName:NSApplicationDidFinishLaunchingNotification object:nil queue:nil usingBlock:^(NSNotification * _Nonnull note) {
        [[VisualEffectDebugger sharedDebugger] installShortcut];
    }];
}

- (void)installShortcut
{
    self.eventMonitor = [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskKeyDown handler:^NSEvent * _Nullable(NSEvent * _Nonnull event) {
        if (event.keyCode == 7 && (event.modifierFlags & (NSEventModifierFlagControl | NSEventModifierFlagOption | NSEventModifierFlagCommand))) {
            [self cycleMaterialsInViewUnderCursor];
            
            return nil;
        } else {
            return event;
        }
    }];
}

- (void)cycleMaterialsInViewUnderCursor
{
    if (!NSApp.isActive) return;
    
    for (NSWindow *window in NSApp.windows) {
        if ([window.title isEqualToString:kSelectionWindowTitle]) continue;
        
        if ([self cycleMaterialsInFocusedVFXViewInWindow:window]) break;
    }
}

- (BOOL)cycleMaterialsInFocusedVFXViewInWindow:(NSWindow *)window
{
    if (!window.isVisible) return NO;
    
    NSPoint p = NSEvent.mouseLocation;
    NSPoint windowPoint = [window convertPointFromScreen:p];
    
    NSArray <NSVisualEffectView *> *views;
    views = [self visualEffectViewsByHitTestingWindow:window atPoint:windowPoint];

    if (!views.count) return NO;
    
    if (views.count > 1) {
        [self showViewPickerForViews:views inWindow:window];
    } else {
        [views.firstObject __gr_cycleMaterials];
    }
    
    return YES;
}

- (void)showViewPickerForViews:(NSArray <NSVisualEffectView *> *)views
                      inWindow:(NSWindow *)window
{
    self.viewPicker = [[NSMenu alloc] initWithTitle:@"View Picker"];
    self.viewPicker.delegate = self;

    for (NSVisualEffectView *view in views) {
        NSString *desc = [self descriptionForView:view];
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:desc action:@selector(cycleMaterialsFromPickerItem:) keyEquivalent:@""];
        item.representedObject = view;
        item.target = self;
        [self.viewPicker addItem:item];
    }
    
    [self.viewPicker popUpMenuPositioningItem:nil atLocation:NSEvent.mouseLocation inView:nil];
}

- (NSString *)descriptionForView:(NSVisualEffectView *)view
{
    NSString *identity = view.description;
    NSString *label = (view.accessibilityLabel) ? [NSString stringWithFormat:@" %@", view.accessibilityLabel] : @"";
    NSString *material = [__VisualEffectDebuggerVFXView nameForMaterial:view.material];
    
    return [NSString stringWithFormat:@"%@%@ %@", identity, label, material];
}

- (void)cycleMaterialsFromPickerItem:(NSMenuItem *)item
{
    [item.representedObject __gr_cycleMaterials];
}

- (NSArray <NSVisualEffectView *> *)visualEffectViewsByHitTestingWindow:(NSWindow *)window
                                                                atPoint:(NSPoint)point
{
    NSMutableArray <NSVisualEffectView *> *output = [NSMutableArray new];
    
    NSView *view = [window.contentView hitTest:point];
    
    while (view != nil) {
        if ([view isKindOfClass:[NSVisualEffectView class]]) {
            [output addObject:(NSVisualEffectView *)view];
        }
        
        view = view.superview;
    }
    
    return output;
}

- (void)menu:(NSMenu *)menu willHighlightItem:(NSMenuItem *)item
{
    NSVisualEffectView *target = item.representedObject;
    if (![target isKindOfClass:[NSVisualEffectView class]]) {
        [self.selectionWindow close];
        return;
    }
    
    NSView *conversionView = (target.superview) ? target.superview : target;
    NSRect frameInWindowCoord = [conversionView convertRect:target.frame toView:nil];
    NSRect frameInScreenCoord = [target.window convertRectToScreen:frameInWindowCoord];
    
    [self.selectionWindow setFrame:frameInScreenCoord display:YES animate:NO];
    
    [self.selectionWindow orderFront:self];
}

- (NSWindow *)selectionWindow
{
    if (_selectionWindow) return _selectionWindow;
    
    _selectionWindow = [[NSPanel alloc] initWithContentRect:NSZeroRect styleMask:NSWindowStyleMaskBorderless backing:NSBackingStoreBuffered defer:NO];
    _selectionWindow.backgroundColor = [NSColor clearColor];
    _selectionWindow.level = NSScreenSaverWindowLevel;
    _selectionWindow.collectionBehavior = NSWindowCollectionBehaviorStationary;
    _selectionWindow.title = kSelectionWindowTitle;
    
    NSView *borderView = [NSView new];
    borderView.wantsLayer = YES;
    borderView.layer = [CALayer layer];
    borderView.layer.borderWidth = 2;
    borderView.layer.borderColor = [NSColor systemTealColor].CGColor;

    _selectionWindow.contentView = borderView;
    
    return _selectionWindow;
}

- (void)menuDidClose:(NSMenu *)menu
{
    [_selectionWindow close];
}

@end






#pragma mark - NSVisualEffectView Runtime Overrides

@implementation __VisualEffectDebuggerVFXView

/// NOTE: Not dynamic by any means. If Apple adds new materials,
/// those will have to be added manually.
+ (NSDictionary <NSNumber *, NSString *> *)materialNames
{
    static dispatch_once_t onceToken;
    static NSDictionary *_names;
    dispatch_once(&onceToken, ^{
        _names = @{
            @(NSVisualEffectMaterialTitlebar): @"Titlebar",
            @(NSVisualEffectMaterialSelection): @"Selection",
            @(NSVisualEffectMaterialMenu): @"Menu",
            @(NSVisualEffectMaterialPopover): @"Popover",
            @(NSVisualEffectMaterialSidebar): @"Sidebar",
            @(NSVisualEffectMaterialHeaderView): @"HeaderView",
            @(NSVisualEffectMaterialSheet): @"Sheet",
            @(NSVisualEffectMaterialWindowBackground): @"WindowBackground",
            @(NSVisualEffectMaterialHUDWindow): @"HUDWindow",
            @(NSVisualEffectMaterialFullScreenUI): @"FullScreenUI",
            @(NSVisualEffectMaterialToolTip): @"ToolTip",
            @(NSVisualEffectMaterialContentBackground): @"ContentBackground",
            @(NSVisualEffectMaterialUnderWindowBackground): @"WindowBackground",
            @(NSVisualEffectMaterialUnderPageBackground): @"PageBackground",
        };
    });
    return _names;
}

+ (NSString *)nameForMaterial:(NSVisualEffectMaterial)material
{
    return [[__VisualEffectDebuggerVFXView materialNames] objectForKey:@(material)];
}

+ (NSArray <NSNumber *> *)availableMaterials
{
    static dispatch_once_t onceToken;
    static NSArray *_materials;
    dispatch_once(&onceToken, ^{
        _materials = @[
            @(NSVisualEffectMaterialTitlebar),
            @(NSVisualEffectMaterialSelection),
            @(NSVisualEffectMaterialMenu),
            @(NSVisualEffectMaterialPopover),
            @(NSVisualEffectMaterialSidebar),
            @(NSVisualEffectMaterialHeaderView),
            @(NSVisualEffectMaterialSheet),
            @(NSVisualEffectMaterialWindowBackground),
            @(NSVisualEffectMaterialHUDWindow),
            @(NSVisualEffectMaterialFullScreenUI),
            @(NSVisualEffectMaterialToolTip),
            @(NSVisualEffectMaterialContentBackground),
            @(NSVisualEffectMaterialUnderWindowBackground),
            @(NSVisualEffectMaterialUnderPageBackground)
        ];
    });
    return _materials;
}

- (void)__gr_didMoveToWindow
{
    [self __gr_original_viewDidMoveToWindow];
    
    [self __gr_updateMaterialsMenu];
}

- (void)__gr_updateMaterialsMenu
{
    NSMenu *debugMenu = [[NSMenu alloc] initWithTitle:@"Visual Effect Debugger"];
    
    for (NSNumber *material in [__VisualEffectDebuggerVFXView availableMaterials]) {
        NSString *name = [__VisualEffectDebuggerVFXView nameForMaterial:material.integerValue];
        if (!name) continue;
        
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:name action:@selector(__gr_handleSelectedMaterialItem:) keyEquivalent:@""];
        item.representedObject = material;
        item.state = (material.integerValue == self.material) ? NSControlStateValueOn : NSControlStateValueOff;
        [debugMenu addItem:item];
    }
    
    self.menu = debugMenu;
}

- (void)__gr_handleSelectedMaterialItem:(NSMenuItem *)sender
{
    self.material = [sender.representedObject integerValue];
    [self __gr_updateMaterialsMenu];
}

- (void)__gr_cycleMaterials
{
    NSArray <NSNumber *> *materials = [__VisualEffectDebuggerVFXView availableMaterials];
    NSNumber *current = @(self.material);
    NSUInteger nextIndex = 0;
    
    NSUInteger idx = [materials indexOfObject:current];
    if (idx != NSNotFound) nextIndex = idx + 1;
    if (nextIndex > materials.count - 1) nextIndex = 0;
        
    self.material = materials[nextIndex].integerValue;
    [self __gr_updateMaterialsMenu];
}

@end

#endif
