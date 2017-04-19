//
//  WWDCAppearance.m
//  WWDC
//
//  Created by Guilherme Rambo on 19/04/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

#import "WWDCAppearance.h"

NSString *const WWDCAppearanceName = @"WWDC";

@interface NSCompositeAppearance: NSAppearance

- (instancetype)initWithAppearances:(NSArray <NSAppearance *> *)appearances;

@end

@implementation WWDCAppearance

+ (NSAppearance *)appearance
{
    NSAppearance *dark = [NSAppearance appearanceNamed:NSAppearanceNameVibrantDark];
    NSAppearance *wwdc = [NSAppearance appearanceNamed:WWDCAppearanceName];
    
    return [[NSClassFromString(@"NSCompositeAppearance") alloc] initWithAppearances:@[wwdc, dark]];
}

@end
