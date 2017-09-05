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
    func timelineDidReceiveForceTouch(at timestamp: Double)

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

    private var annotationWindowController: PUIAnnotationWindowController?

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

        layer?.addSublayer(borderLayer)

        // Buffering bar

        bufferingProgressLayer = PUIBufferLayer()
        bufferingProgressLayer.frame = bounds
        bufferingProgressLayer.cornerRadius = Metrics.cornerRadius
        bufferingProgressLayer.masksToBounds = true

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

        selectedAnnotation = nil
        delegate?.timelineDidSelectAnnotation(nil)
        unhighlightCurrentHoveredAnnotationIfNeeded()

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

                    self.viewDelegate?.timelineDidReceiveForceTouch(at: timestamp)

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
                borderLayer.borderColor = NSColor.highlightedPlayerBorder.cgColor
            }

            ghostProgressLayer.animate {
                ghostProgressLayer.opacity = 1
            }
        } else {
            borderLayer.animate {
                borderLayer.borderColor = NSColor.playerBorder.cgColor
            }

            ghostProgressLayer.animate {
                ghostProgressLayer.opacity = 0
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

    private var annotationLayers: [PUIAnnotationLayer] = []

    private func layoutAnnotations(distributeOnly: Bool = false) {
        guard hasValidMediaDuration else { return }

        annotationLayers.forEach({ $0.removeFromSuperlayer() })
        annotationLayers.removeAll()

        let sf = window?.screen?.backingScaleFactor ?? 1

        annotationLayers = annotations.map { annotation in
            let l = PUIAnnotationLayer()

            l.backgroundColor = NSColor.playerHighlight.cgColor
            l.name = annotation.identifier
            l.zPosition = 999
            l.cornerRadius = Metrics.annotationBubbleDiameter / 2
            l.borderColor = NSColor.white.cgColor
            l.borderWidth = 0

            let textLayer = PUIBoringTextLayer()

            textLayer.string = attributedString(for: annotation.timestamp)
            textLayer.contentsScale = sf
            textLayer.opacity = 0

            l.attach(layer: textLayer, attribute: .top, spacing: 8)

            return l
        }

        annotations.forEach { annotation in
            guard let l = annotationLayers.first(where: { $0.name == annotation.identifier }) else { return }

            layoutAnnotationLayer(l, for: annotation, with: Metrics.annotationBubbleDiameter)
        }

        annotationLayers.forEach({ layer?.addSublayer($0) })
    }

    private func attributedString(for timestamp: Double) -> NSAttributedString {
        let pStyle = NSMutableParagraphStyle()
        pStyle.alignment = .center

        let timeTextAttributes: [String: Any] = [
            NSFontAttributeName: NSFont.systemFont(ofSize: 14, weight: NSFontWeightMedium),
            NSForegroundColorAttributeName: NSColor.playerHighlight,
            NSParagraphStyleAttributeName: pStyle
        ]

        let timeStr = String(timestamp: timestamp) ?? ""

        return NSAttributedString(string: timeStr, attributes: timeTextAttributes)
    }

    private func layoutAnnotationLayer(_ layer: PUIBoringLayer, for annotation: PUITimelineAnnotation, with diameter: CGFloat, animated: Bool = false) {
        guard hasValidMediaDuration else { return }

        let x: CGFloat = (CGFloat(annotation.timestamp / mediaDuration) * bounds.width) - (diameter / 2)
        let y: CGFloat = bounds.height / 2 - diameter / 2

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

        if let (sa, _) = selectedAnnotation {
            if sa.identifier == annotation.identifier {
                configureAnnotationLayerAsHighlighted(layer: layer)
            }
        }
    }

    private var hoveredAnnotation: (PUITimelineAnnotation, PUIAnnotationLayer)?
    private var selectedAnnotation: (PUITimelineAnnotation, PUIAnnotationLayer)? {
        didSet {
            unhighlight(annotationTuple: oldValue)

            if selectedAnnotation != nil {
                showAnnotationWindow()
                hoveredAnnotation = nil
            } else {
                unhighlightCurrentHoveredAnnotationIfNeeded()
                hideAnnotationWindow()
            }
        }
    }

    private func annotationUnderMouse(with event: NSEvent, diameter: CGFloat = Metrics.annotationBubbleDiameter) -> (annotation: PUITimelineAnnotation, layer: PUIAnnotationLayer)? {
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
        guard let (ha, hal) = hoveredAnnotation else { return }

        if let (sa, _) = selectedAnnotation {
            guard sa.identifier != ha.identifier else { return }
        }

        mouseOut(ha, layer: hal)

        hoveredAnnotation = nil
    }

    private func unhighlight(annotationTuple: (PUITimelineAnnotation, PUIAnnotationLayer)?) {
        guard let (sa, sal) = annotationTuple else { return }

        mouseOut(sa, layer: sal)
    }

    private func mouseOver(_ annotation: PUITimelineAnnotation, layer: PUIAnnotationLayer) {
        CATransaction.begin()
        defer { CATransaction.commit() }

        layer.animate {
            configureAnnotationLayerAsHighlighted(layer: layer)
        }

        delegate?.timelineDidHighlightAnnotation(annotation)
    }

    private func configureAnnotationLayerAsHighlighted(layer: PUIBoringLayer) {
        guard let layer = layer as? PUIAnnotationLayer else { return }

        let s = Metrics.annotationBubbleDiameterHoverScale
        layer.transform = CATransform3DMakeScale(s, s, s)
        layer.borderWidth = 1
        layer.attachedLayer.animate { layer.attachedLayer.opacity = 1 }
    }

    private func mouseOut(_ annotation: PUITimelineAnnotation, layer: PUIAnnotationLayer) {
        CATransaction.begin()
        defer { CATransaction.commit() }

        layer.animate {
            layer.transform = CATransform3DIdentity
            layer.borderWidth = 0
            layer.attachedLayer.animate { layer.attachedLayer.opacity = 0 }
        }

        delegate?.timelineDidHighlightAnnotation(nil)
    }

    private enum AnnotationDragMode {
        case none
        case delete
        case move
    }

    private func mouseDown(_ annotation: PUITimelineAnnotation, layer: PUIAnnotationLayer, originalEvent: NSEvent) {
        let startingPoint = convert(originalEvent.locationInWindow, from: nil)
        let originalPosition = layer.position

        let originalTimestampString = layer.attachedLayer.string

        var cancelled = true

        let canDelete = delegate?.timelineCanDeleteAnnotation(annotation) ?? false
        let canMove = delegate?.timelineCanMoveAnnotation(annotation) ?? false

        var mode: AnnotationDragMode = .none {
            didSet {
                if oldValue != .delete && mode == .delete {
                    NSCursor.disappearingItem().push()
                    layer.attachedLayer.animate { layer.attachedLayer.opacity = 0 }
                } else if oldValue == .delete && mode != .delete {
                    NSCursor.pop()
                    layer.attachedLayer.animate { layer.attachedLayer.opacity = 1 }
                } else if mode == .none && cancelled {
                    layer.animate { layer.position = originalPosition }
                    updateAnnotationTextLayer(with: originalTimestampString)
                }
            }
        }

        func makeTimestamp(for point: CGPoint) -> Double {
            var timestamp = Double(point.x / bounds.width) * mediaDuration

            if timestamp < 0 {
                timestamp = 0
            } else if timestamp > mediaDuration {
                timestamp = mediaDuration
            }

            return timestamp
        }

        func updateAnnotationTextLayer(at point: CGPoint) {
            let timestamp = makeTimestamp(for: point)

            layer.attachedLayer.string = attributedString(for: timestamp)
        }

        func updateAnnotationTextLayer(with string: Any?) {
            guard let str = string else { return }

            layer.attachedLayer.string = str
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

                    let timestamp = makeTimestamp(for: point)

                    self.delegate?.timelineDidMoveAnnotation(annotation, to: timestamp)
                case .none:
                    self.selectedAnnotation = (annotation, layer)
                    self.delegate?.timelineDidSelectAnnotation(annotation)
                }

                mode = .none
                self.hoveredAnnotation = nil
                updateAnnotationTextLayer(at: point)

                stop.pointee = true
            case .leftMouseDragged:
                self.selectedAnnotation = nil

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

                    updateAnnotationTextLayer(at: point)
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

    // MARK: - Annotation editing management

    private var annotationCommandsMonitor: Any?
    private var currentAnnotationEditor: NSViewController?

    private func showAnnotationWindow() {
        guard let (annotation, annotationLayer) = selectedAnnotation else { return }
        guard let controller = delegate?.viewControllerForTimelineAnnotation(annotation) else { return }

        currentAnnotationEditor = controller

        if annotationWindowController == nil {
            annotationWindowController = PUIAnnotationWindowController()
        }

        guard let windowController = annotationWindowController else { return }
        guard let annotationWindow = windowController.window else { return }
        guard let contentView = annotationWindowController?.window?.contentView else { return }

        controller.view.frame = contentView.bounds
        controller.view.autoresizingMask = [.viewWidthSizable, .viewHeightSizable]
        contentView.addSubview(controller.view)

        let layerRect = convertFromLayer(annotationLayer.frame)
        let windowRect = convert(layerRect, to: nil)
        guard var screenRect = window?.convertToScreen(windowRect) else { return }

        screenRect.origin.y += 56
        screenRect.origin.x -= round((contentView.bounds.width / 2) - annotationLayer.bounds.width)

        annotationWindow.alphaValue = 0

        window?.addChildWindow(annotationWindow, ordered: .above)
        annotationWindow.setFrameOrigin(screenRect.origin)

        if annotation.isEmpty {
            annotationWindow.makeKeyAndOrderFront(nil)
        } else {
            annotationWindow.orderFront(nil)
        }

        annotationWindow.animator().alphaValue = 1

        enum AnnotationKeyCommand: UInt16 {
            case escape = 53
            case enter = 36
        }

        annotationCommandsMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyUp]) { event in
            guard let command = AnnotationKeyCommand(rawValue: event.keyCode) else { return event }

            switch command {
            case .enter:
                if event.modifierFlags.contains(.command) {
                    fallthrough
                }
            case .escape:
                self.selectedAnnotation = nil
                self.unhighlightCurrentHoveredAnnotationIfNeeded()
            }

            return event
        }
    }

    private func hideAnnotationWindow() {
        if let monitor = annotationCommandsMonitor {
            NSEvent.removeMonitor(monitor)
            annotationCommandsMonitor = nil
        }

        NSAnimationContext.beginGrouping()
        NSAnimationContext.current().completionHandler = {
            self.annotationWindowController?.close()
            self.currentAnnotationEditor?.view.removeFromSuperview()
            self.currentAnnotationEditor = nil
            self.annotationWindowController = nil
        }
        annotationWindowController?.window?.animator().alphaValue = 0
        NSAnimationContext.endGrouping()
    }

    var isEditingAnnotation: Bool {
        return annotationWindowController != nil
    }

}
