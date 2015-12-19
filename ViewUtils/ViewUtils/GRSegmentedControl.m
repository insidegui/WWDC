//
//  GRSegmentedControl.m
//  ViewUtils
//
//  Created by Guilherme Rambo on 10/3/15.
//  Copyright © 2015 Guilherme Rambo. All rights reserved.
//

#import "GRSegmentedControl.h"

@interface NSSegmentedCell (Private)
- (NSRect)rectForSegment:(NSInteger)segment inFrame:(NSRect)frame;
- (double)_segmentedMenuDelayTime;
@end

@interface GRSegmentedItemTextCell : NSTextFieldCell
@end

@interface GRSegmentedCell : NSSegmentedCell

@property (nonatomic, readonly) GRSegmentedControl *control;
@property (nonatomic, assign) NSInteger clickHighlightedSegment;

@end

@implementation GRSegmentedCell
{
    id _mouseUpMonitor;
}

- (void)awakeFromNib
{
    [super awakeFromNib];
    
    _clickHighlightedSegment = -1;
}

- (GRSegmentedControl *)control
{
    return (GRSegmentedControl *)self.controlView;
}

- (void)setMenu:(NSMenu *)menu forSegment:(NSInteger)segment
{
    NSMenu *existingMenu = [self menuForSegment:segment];
    if (existingMenu) [[NSNotificationCenter defaultCenter] removeObserver:existingMenu name:NSMenuDidEndTrackingNotification object:existingMenu];
    
    [super setMenu:menu forSegment:segment];
    
    [[NSNotificationCenter defaultCenter] addObserverForName:NSMenuDidEndTrackingNotification object:menu queue:nil usingBlock:^(NSNotification * _Nonnull note) {
        self.clickHighlightedSegment = -1;
    }];
}

- (NSRect)drawingRectForBounds:(NSRect)theRect
{
    if (self.control.usesCocoaLook) return [super drawingRectForBounds:theRect];
        
    NSRect rect = [super drawingRectForBounds:theRect];
    if ([NSProcessInfo processInfo].operatingSystemVersion.majorVersion == 10 &&
        [NSProcessInfo processInfo].operatingSystemVersion.minorVersion == 11) {
        rect.size.height += 2.0;
    }
    return rect;
}

#define kDefaultBorderColor [NSColor colorWithCalibratedRed:0.0 green:0.5 blue:1.0 alpha:0.9]
#define kDefaultSelectedBackgroundColor [NSColor colorWithCalibratedRed:0.0 green:0.5 blue:1.0 alpha:0.2]
#define kDefaultTextColor kDefaultBorderColor

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
    if (self.control.usesCocoaLook) return [super drawWithFrame:cellFrame inView:controlView];
    
    CGContextRef ctx = [NSGraphicsContext currentContext].CGContext;
    CGContextSetBlendMode(ctx, kCGBlendModeOverlay);
    
    CGFloat radius = 4.0;

    NSRect drawingRect = [self drawingRectForBounds:cellFrame];
    drawingRect.origin.y -= 0.5;
    drawingRect.origin.x -= 0.5;
    
    NSBezierPath *rim = [NSBezierPath bezierPathWithRoundedRect:drawingRect xRadius:radius yRadius:radius];
    
    if (self.control.borderColor) {
        [self.control.borderColor setStroke];
    } else {
        [kDefaultBorderColor setStroke];
    }
    if (self.control.segmentBackgroundColor) {
        [self.control.segmentBackgroundColor setFill];
        [rim fill];
    }
    
    [rim stroke];
    
    for (NSInteger i = 0; i < self.segmentCount; i++) {
        @autoreleasepool {
            [self drawSegment:i inFrame:cellFrame withView:controlView clippedByPath:rim];
        }
    }
}

- (void)drawSegment:(NSInteger)segment inFrame:(NSRect)frame withView:(NSView *)controlView clippedByPath:(NSBezierPath *)clippingPath
{
    [clippingPath addClip];
    
    NSRect segmentRect = [self rectForSegment:segment inFrame:frame];

    if (segment < self.segmentCount-1) {
        // draw right separator
        NSRect separatorRect = NSMakeRect(segmentRect.origin.x+NSWidth(segmentRect), 0, 1.0, NSHeight(segmentRect));
        if (self.control.borderColor) {
            [self.control.borderColor setFill];
        } else {
            [kDefaultBorderColor setFill];
        }
        NSRectFill(separatorRect);
    }
    
    NSString *label = [self labelForSegment:segment];
    if (!label) return;

    NSRect textRect = NSInsetRect(segmentRect, 1.0, 1.0);
    if (segment == self.segmentCount-1) {
        textRect.origin.x -= 1.0;
    } else if (segment == 0) {
        textRect.origin.x += 1.0;
    }
    
    NSColor *fillColor;
    NSColor *textColor;
    
    if ([self shouldDrawActiveForSegment:segment]) {
        if (self.control.activeSegmentTextColor) {
            textColor = self.control.activeSegmentTextColor;
        } else {
            textColor = kDefaultTextColor;
        }
        if (self.control.activeSegmentBackgroundColor) {
            fillColor = self.control.activeSegmentBackgroundColor;
        } else {
            fillColor = kDefaultSelectedBackgroundColor;
        }
    } else {
        if (self.control.segmentTextColor) {
            textColor = self.control.segmentTextColor;
        } else {
            textColor = kDefaultTextColor;
        }
        if (self.control.segmentBackgroundColor) {
            fillColor = self.control.segmentBackgroundColor;
        }
    }
    if (fillColor) {
        [[NSGraphicsContext currentContext] saveGraphicsState];
        
        NSRect fillRect = NSInsetRect(segmentRect, 2.0, 1.0);
        if (segment == 0) {
            fillRect.size.width += 5.0;
            fillRect.origin.x += 1.0;
            [[NSBezierPath bezierPathWithRoundedRect:fillRect xRadius:4.0 yRadius:4.0] addClip];
        } else if (segment == self.segmentCount - 1) {
            fillRect.size.width += 5.0;
            fillRect.origin.x -= 5.0;
            [[NSBezierPath bezierPathWithRoundedRect:fillRect xRadius:4.0 yRadius:4.0] addClip];
        }
        
        if (segment > 0) {
            segmentRect.origin.x += 1.0;
            segmentRect.size.width -= 1.0;
        }
        [[NSBezierPath bezierPathWithRect:segmentRect] addClip];
        
        [fillColor setFill];
        NSRectFill(segmentRect);
        
        [[NSGraphicsContext currentContext] restoreGraphicsState];
    }
    

    if ([self shouldDrawActiveForSegment:segment]) {
        [[NSGraphicsContext currentContext] saveGraphicsState];
        [[NSGraphicsContext currentContext] setCompositingOperation:NSCompositeSourceOver];
    }
    
    NSTextFieldCell *cell = [[GRSegmentedItemTextCell alloc] initTextCell:label];
    cell.font = self.font;
    cell.textColor = textColor;
    cell.alignment = NSCenterTextAlignment;
    cell.lineBreakMode = NSLineBreakByTruncatingTail;
    [cell drawWithFrame:textRect inView:controlView];
    
    if ([self shouldDrawActiveForSegment:segment]) [[NSGraphicsContext currentContext] restoreGraphicsState];
}

- (BOOL)shouldDrawActiveForSegment:(NSInteger)segment
{
    return [self isSelectedForSegment:segment] || self.clickHighlightedSegment == segment;
}

- (void)setClickHighlightedSegment:(NSInteger)clickHighlightedSegment
{
    _clickHighlightedSegment = clickHighlightedSegment;
    
    [self.controlView setNeedsDisplay:YES];
}

- (BOOL)trackMouse:(NSEvent *)theEvent inRect:(NSRect)cellFrame ofView:(NSView *)controlView untilMouseUp:(BOOL)flag
{
    NSPoint ourPoint = [controlView convertPoint:theEvent.locationInWindow fromView:nil];
    
    for (NSInteger i = 0; i < self.segmentCount; i++) {
        if (NSIntersectsRect(NSMakeRect(ourPoint.x, ourPoint.y, 1.0, 1.0), [self rectForSegment:i inFrame:cellFrame])) {
            self.clickHighlightedSegment = i;
            break;
        } else {
            self.clickHighlightedSegment = -1;
        }
    }

    return [super trackMouse:theEvent inRect:cellFrame ofView:controlView untilMouseUp:flag];
}

- (double)_segmentedMenuDelayTime
{
    if (self.control.showsMenuImmediately) {
        return 0.0;
    } else {
        return [super _segmentedMenuDelayTime];
    }
}

- (void)stopTracking:(NSPoint)lastPoint at:(NSPoint)stopPoint inView:(NSView *)controlView mouseIsUp:(BOOL)flag
{
    if (flag) self.clickHighlightedSegment = -1;
    
    return [super stopTracking:lastPoint at:stopPoint inView:controlView mouseIsUp:flag];
}

@end

@implementation GRSegmentedControl

- (BOOL)canSmoothFontsInLayer
{
    return YES;
}

+ (Class)cellClass
{
    return [GRSegmentedCell class];
}

- (void)addSubview:(NSView *)aView
{
    // the default implementation of NSSegmentedControl uses subviews for the text,
    // we draw the text manually, so we don't allow addSubview: here
    return;
}

@end

@implementation GRSegmentedItemTextCell

- (BOOL)canSmoothFontsInFrame:(NSRect)frame forLayerBackedView:(NSView *)view
{
    return YES;
}

@end