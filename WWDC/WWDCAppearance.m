//
//  WWDCAppearance.m
//  WWDC
//
//  Created by Guilherme Rambo on 19/04/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

#import "WWDCAppearance.h"

#import "WWDC-Swift.h"

NSString *const WWDCAppearanceName = @"WWDC";

@interface NSCompositeAppearance: NSAppearance

- (instancetype)initWithAppearances:(NSArray <NSAppearance *> *)appearances;

@end

@implementation WWDCAppearance

+ (NSAppearance *)appearance
{
    if (@available(macOS 10.14, *)) {
        return [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];
    } else {
        NSAppearance *dark = [NSAppearance appearanceNamed:NSAppearanceNameVibrantDark];
        NSAppearance *wwdc = [NSAppearance appearanceNamed:WWDCAppearanceName];
        
        return [[NSClassFromString(@"NSCompositeAppearance") alloc] initWithAppearances:@[wwdc, dark]];
    }
}

+ (NSShadow *)toolTipTextShadow
{
    static NSShadow *_tttShadow;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _tttShadow = [[NSShadow alloc] init];
        _tttShadow.shadowBlurRadius = 1;
        _tttShadow.shadowOffset = NSMakeSize(0.5, -1.0);
        _tttShadow.shadowColor = [NSColor colorWithCalibratedWhite:0.0 alpha:0.8];
    });
    
    return _tttShadow;
}

+ (NSDictionary *)toolTipTextAttributes
{
    static NSDictionary *_tttA;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _tttA = @{
                  NSFontAttributeName: [NSFont toolTipsFontOfSize:0],
                  NSForegroundColorAttributeName: [NSColor primaryText],
                  NSShadowAttributeName: self.toolTipTextShadow
                  };
    });
    
    return _tttA;
}

@end

@interface NSToolTipManager : NSObject
@end

@implementation NSToolTipManager (WWDCOverrides)

- (NSColor *)toolTipBackgroundColor
{
    return [NSColor listBackground];
}

- (NSDictionary *)toolTipAttributes
{
    return [WWDCAppearance toolTipTextAttributes];
}

@end
