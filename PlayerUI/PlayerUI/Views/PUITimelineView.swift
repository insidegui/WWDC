//
//  PUITimelineView.swift
//  PlayerProto
//
//  Created by Guilherme Rambo on 28/04/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
import AVFoundation

protocol PUITimelineViewDelegate: class {
    
    func timelineViewWillBeginInteractiveSeek()
    func timelineViewDidSeek(to progress: Double)
    func timelineViewDidFinishInteractiveSeek()
    
}

public final class PUITimelineView: NSView {
    
    // MARK: - Public API
    
    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        buildUI()
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        
        buildUI()
    }
    
    public override var intrinsicContentSize: NSSize {
        return NSSize(width: -1, height: 8)
    }
    
    public weak var delegate: PUITimelineDelegate?
    
    public var bufferingProgress: Double = 0 {
        didSet {
            layoutBufferingLayer()
        }
    }
    
    public var playbackProgress: Double = 0 {
        didSet {
            layoutPlaybackLayer()
        }
    }
    
    public var annotations: [PUITimelineAnnotation] = [] {
        didSet {
            layoutAnnotations()
        }
    }
    
    public var mediaDuration: Double = 0 {
        didSet {
            needsLayout = true
        }
    }
    
    public var hasValidMediaDuration: Bool {
        return AVPlayer.validateMediaDurationWithSeconds(mediaDuration)
    }
    
    // MARK: - Private API
    
    weak var viewDelegate: PUITimelineViewDelegate?
    
    var loadedSegments = Set<PUIBufferSegment>() {
        didSet {
            bufferingProgressLayer.segments = loadedSegments
        }
    }
    
    struct Metrics {
        static let cornerRadius: CGFloat = 4
        static let annotationBubbleDiameter: CGFloat = 12
        static let annotationBubbleDiameterHoverScale: CGFloat = 1.3
        static let annotationDragThresholdVertical: CGFloat = 15
        static let annotationDragThresholdHorizontal: CGFloat = 6
    }
    
    private var borderLayer: PUIBoringLayer!
    private var bufferingProgressLayer: PUIBufferLayer!
    private var playbackProgressLayer: PUIBoringLayer!
    private var ghostProgressLayer: PUIBoringLayer!
    
    private func buildUI() {
        wantsLayer = true
        layer = PUIBoringLayer()
        
        // Main border
        
        borderLayer = PUIBoringLayer()
        borderLayer.borderColor = NSColor.playerBorder.cgColor
        borderLayer.borderWidth = 1.0
        borderLayer.frame = bounds
        borderLayer.cornerRadius = Metrics.cornerRadius
        borderLayer.masksToBounds = true
        
        layer?.addSublayer(borderLayer)
        
        // Buffering bar
        
        bufferingProgressLayer = PUIBufferLayer()
        bufferingProgressLayer.frame = bounds
        bufferingProgressLayer.cornerRadius = Metrics.cornerRadius
        bufferingProgressLayer.masksToBounds = true
        // TODO: hide buffering layer only when media is not a stream
        bufferingProgressLayer.opacity = 0
        
        layer?.addSublayer(bufferingProgressLayer)
        
        // Playback bar
        
        playbackProgressLayer = PUIBoringLayer()
        playbackProgressLayer.backgroundColor = NSColor.playerProgress.cgColor
        playbackProgressLayer.frame = bounds
        playbackProgressLayer.cornerRadius = Metrics.cornerRadius
        playbackProgressLayer.masksToBounds = true
        
        layer?.addSublayer(playbackProgressLayer)
        
        // Ghost bar
        
        ghostProgressLayer = PUIBoringLayer()
        ghostProgressLayer.backgroundColor = NSColor.playerProgress.withAlphaComponent(0.5).cgColor
        ghostProgressLayer.frame = bounds
        ghostProgressLayer.cornerRadius = Metrics.cornerRadius
        ghostProgressLayer.masksToBounds = true
        
        layer?.addSublayer(ghostProgressLayer)
    }
    
    public override func layout() {
        super.layout()
        
        borderLayer.frame = bounds
        
        layoutBufferingLayer()
        layoutPlaybackLayer()
        layoutAnnotations(distributeOnly: true)
    }
    
    private func layoutBufferingLayer() {
        bufferingProgressLayer.frame = bounds
    }
    
    private func layoutPlaybackLayer() {
        guard hasValidMediaDuration else { return }
        
        let playbackWidth = bounds.width * CGFloat(playbackProgress)
        var playbackRect = bounds
        playbackRect.size.width = playbackWidth
        playbackProgressLayer.frame = playbackRect
    }
    
    private var hasMouseInside: Bool = false {
        didSet {
            reactToMouse()
        }
    }
    
    private var mouseTrackingArea: NSTrackingArea!
    
    public override func updateTrackingAreas() {
        super.updateTrackingAreas()
        
        if mouseTrackingArea != nil {
            removeTrackingArea(mouseTrackingArea)
        }
        
        let options: NSTrackingAreaOptions = [.mouseEnteredAndExited, .mouseMoved, .activeInActiveApp]
        let trackingBounds = bounds.insetBy(dx: -2.5, dy: -7)
        mouseTrackingArea = NSTrackingArea(rect: trackingBounds, options: options, owner: self, userInfo: nil)
        
        addTrackingArea(mouseTrackingArea)
    }
    
    public override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        
        hasMouseInside = true
    }
    
    public override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        
        hasMouseInside = false
        
        unhighlightCurrentHoveredAnnotationIfNeeded()
    }
    
    public override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        
        guard hasMouseInside else { return }
        
        updateGhostProgress(with: event)
        trackMouseAgainstAnnotations(with: event)
    }
    
    private func updateGhostProgress(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        
        guard point.x > 0 && point.x < bounds.width else {
            return
        }
        
        let ghostWidth = point.x
        var ghostRect = bounds
        ghostRect.size.width = ghostWidth
        ghostProgressLayer.frame = ghostRect
    }
    
    public override var mouseDownCanMoveWindow: Bool {
        set { }
        get { return false }
    }
    
    public override func mouseDown(with event: NSEvent) {
        if let targetAnnotation = hoveredAnnotation {
            mouseDown(targetAnnotation.0, layer: targetAnnotation.1, originalEvent: event)
            return
        }
        
        var startedInteractiveSeek = false
        
        window?.trackEvents(matching: [.pressure, .leftMouseUp, .leftMouseDragged, .tabletPoint], timeout: NSEventDurationForever, mode: .eventTrackingRunLoopMode) { e, stop in
            let point = self.convert(e.locationInWindow, from: nil)
            let progress = Double(point.x / self.bounds.width)
            
            switch e.type {
            case .leftMouseUp:
                if startedInteractiveSeek {
                    self.viewDelegate?.timelineViewDidFinishInteractiveSeek()
                } else {
                    // single click seek
                    self.viewDelegate?.timelineViewDidSeek(to: progress)
                }
                
                stop.pointee = true
            case .pressure, .tabletPoint:
                switch e.touchForce {
                case .forceTouch:
                    guard self.hasValidMediaDuration else {
                        stop.pointee = true
                        return
                    }
                    
                    let timestamp = self.mediaDuration * progress
                    
                    DebugLog("Force touch at \(timestamp)s")
                    
                    self.delegate?.timelineDidReceiveForceTouch(at: timestamp)
                    
                    stop.pointee = true
                default: break
                }
            case .leftMouseDragged:
                if !startedInteractiveSeek {
                    startedInteractiveSeek = true
                    self.viewDelegate?.timelineViewWillBeginInteractiveSeek()
                }
                
                self.viewDelegate?.timelineViewDidSeek(to: progress)
                
                self.ghostProgressLayer.opacity = 0
            default: break
            }
        }
        
        NSApp.discardEvents(matching: .leftMouseDown, before: nil)
    }
    
    private func reactToMouse() {
        if hasMouseInside {
            borderLayer.animate {
                self.borderLayer.borderColor = NSColor.highlightedPlayerBorder.cgColor
            }
            
            ghostProgressLayer.animate {
                self.ghostProgressLayer.opacity = 1
            }
        } else {
            borderLayer.animate {
                self.borderLayer.borderColor = NSColor.playerBorder.cgColor
            }
            
            ghostProgressLayer.animate {
                self.ghostProgressLayer.opacity = 0
            }
        }
    }
    
    public override var allowsVibrancy: Bool {
        return true
    }
    
    public override var isFlipped: Bool {
        return true
    }
    
    // MARK: - Annotation management
    
    private var annotationLayers: [PUIBoringLayer] = []
    
    private func layoutAnnotations(distributeOnly: Bool = false) {
        guard hasValidMediaDuration else { return }
        
        annotationLayers.forEach({ $0.removeFromSuperlayer() })
        annotationLayers.removeAll()
        
        annotationLayers = annotations.map { annotation in
            let l = PUIBoringLayer()
            
            l.backgroundColor = NSColor.playerHighlight.cgColor
            l.name = annotation.identifier
            l.zPosition = 50
            l.cornerRadius = Metrics.annotationBubbleDiameter / 2
            l.borderColor = NSColor.white.cgColor
            l.borderWidth = 0
            
            return l
        }
        
        annotations.forEach { annotation in
            guard let l = annotationLayers.first(where: { $0.name == annotation.identifier }) else { return }
            
            self.layoutAnnotationLayer(l, for: annotation, with: Metrics.annotationBubbleDiameter)
        }
        
        annotationLayers.forEach({ self.layer?.addSublayer($0) })
    }
    
    private func layoutAnnotationLayer(_ layer: PUIBoringLayer, for annotation: PUITimelineAnnotation, with diameter: CGFloat, animated: Bool = false) {
        guard hasValidMediaDuration else { return }
        
        let x: CGFloat = (CGFloat(annotation.timestamp / self.mediaDuration) * self.bounds.width) - (diameter / 2)
        let y: CGFloat = self.bounds.height / 2 - diameter / 2
        
        let f = CGRect(x: x, y: y, width: diameter, height: diameter)
        
        if animated {
            layer.animate {
                layer.frame = f
                layer.cornerRadius = f.width / 2
            }
        } else {
            layer.frame = f
            layer.cornerRadius = f.width / 2
        }
    }
    
    private var hoveredAnnotation: (PUITimelineAnnotation, PUIBoringLayer)?
    
    private func annotationUnderMouse(with event: NSEvent, diameter: CGFloat = Metrics.annotationBubbleDiameter) -> (annotation: PUITimelineAnnotation, layer: PUIBoringLayer)? {
        var point = convert(event.locationInWindow, from: nil)
        point.x -= diameter / 2
        
        let s = CGSize(width: diameter, height: diameter)
        let testRect = CGRect(origin: point, size: s)
        
        guard let annotationLayer = annotationLayers.first(where: { $0.frame.intersects(testRect) }) else { return nil }
        
        guard let name = annotationLayer.name else { return nil }
        
        guard let annotation = annotations.first(where: { $0.identifier == name }) else { return nil }
        
        return (annotation: annotation, layer: annotationLayer)
    }
    
    private func trackMouseAgainstAnnotations(with event: NSEvent) {
        guard let (annotation, annotationLayer) = annotationUnderMouse(with: event) else {
            unhighlightCurrentHoveredAnnotationIfNeeded()
            
            return
        }
        
        hoveredAnnotation = (annotation, annotationLayer)
        
        mouseOver(annotation, layer: annotationLayer)
    }
    
    private func unhighlightCurrentHoveredAnnotationIfNeeded() {
        guard let (ha, hal) = self.hoveredAnnotation else { return }
        
        mouseOut(ha, layer: hal)
    }
    
    private func mouseOver(_ annotation: PUITimelineAnnotation, layer: PUIBoringLayer) {
        CATransaction.begin()
        defer { CATransaction.commit() }
        
        layer.animate {
            let s = Metrics.annotationBubbleDiameterHoverScale
            layer.transform = CATransform3DMakeScale(s, s, s)
            layer.borderWidth = 1
        }
        
        delegate?.timelineDidHighlightAnnotation(annotation)
    }
    
    private func mouseOut(_ annotation: PUITimelineAnnotation, layer: PUIBoringLayer) {
        CATransaction.begin()
        defer { CATransaction.commit() }
        
        layer.animate {
            layer.transform = CATransform3DIdentity
            layer.borderWidth = 0
        }
        
        delegate?.timelineDidHighlightAnnotation(nil)
    }
    
    private enum AnnotationDragMode {
        case none
        case delete
        case move
    }
    
    private func mouseDown(_ annotation: PUITimelineAnnotation, layer: PUIBoringLayer, originalEvent: NSEvent) {
        let startingPoint = self.convert(originalEvent.locationInWindow, from: nil)
        let originalPosition = layer.position
        
        var cancelled = true
        
        let canDelete = delegate?.timelineCanDeleteAnnotation(annotation) ?? false
        let canMove = delegate?.timelineCanMoveAnnotation(annotation) ?? false
        
        var mode: AnnotationDragMode = .none {
            didSet {
                if oldValue != .delete && mode == .delete {
                    NSCursor.disappearingItem().push()
                } else if oldValue == .delete && mode != .delete {
                    NSCursor.pop()
                } else if mode == .none && cancelled {
                    layer.animate { layer.position = originalPosition }
                }
            }
        }
        
        window?.trackEvents(matching: [.leftMouseUp, .leftMouseDragged, .keyUp], timeout: NSEventDurationForever, mode: .eventTrackingRunLoopMode) { event, stop in
            let point = self.convert(event.locationInWindow, from: nil)
            
            switch event.type {
            case .leftMouseUp:
                switch mode {
                case .delete:
                    cancelled = false
                    
                    // poof
                    NSShowAnimationEffect(.poof, NSEvent.mouseLocation(), .zero, nil, nil, nil)
                    
                    CATransaction.begin()
                    CATransaction.setCompletionBlock { layer.removeFromSuperlayer() }
                    layer.animate {
                        layer.transform = CATransform3DMakeScale(0, 0, 0)
                        layer.opacity = 0
                    }
                    CATransaction.commit()
                    
                    self.delegate?.timelineDidDeleteAnnotation(annotation)
                case .move:
                    cancelled = false
                    
                    let timestamp = Double(point.x) / self.mediaDuration
                    
                    self.delegate?.timelineDidMoveAnnotation(annotation, to: timestamp)
                default: break
                }
                mode = .none
                stop.pointee = true
            case .leftMouseDragged:
                if mode != .delete {
                    guard point.x - layer.bounds.width / 2 > 0 else { return }
                    guard point.x < self.borderLayer.frame.width - layer.bounds.width / 2 else { return }
                }
                
                let verticalDiff = startingPoint.y - point.y
                let horizontalDiff = startingPoint.x - point.x
                
                var newPosition = layer.position
                
                if abs(verticalDiff) > Metrics.annotationDragThresholdVertical && canDelete {
                    newPosition = point
                    mode = .delete
                } else if abs(horizontalDiff) > Metrics.annotationDragThresholdHorizontal && canMove {
                    newPosition.y = originalPosition.y
                    newPosition.x = point.x
                    mode = .move
                } else {
                    layer.position = originalPosition
                    mode = .none
                }
                
                if mode != .none {
                    layer.position = newPosition
                }
            case .keyUp:
                // cancel with ESC
                if event.keyCode == 53 {
                    mode = .none
                    
                    layer.animate {
                        layer.position = originalPosition
                    }
                    
                    stop.pointee = true
                }
            default: break
            }
        }
    }
    
}
