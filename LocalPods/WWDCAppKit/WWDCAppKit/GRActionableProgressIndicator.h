//
//  GRActionableProgressIndicator.h
//  WWDCAppKit
//
//  Created by Guilherme Rambo on 01/05/15.
//  Copyright (c) 2015 Guilherme Rambo. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface GRActionableProgressIndicator : NSProgressIndicator

@property (assign) id target;
@property (assign) SEL action;
@property (assign) SEL doubleAction;

@end
