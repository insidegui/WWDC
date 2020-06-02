//
//  PUITimelineView.swift
//  PlayerProto
//
//  Created by Guilherme Rambo on 28/04/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
import AVFoundation
import os.log

protocol PUITimelineViewDelegate: class {

    func timelineViewWillBeginInteractiveSeek()
    func timelineViewDidSeek(to progress: Double)
    func timelineViewDidFinishInteractiveSeek()
    func timelineDidReceiveForceTouch(at timestamp: Double)

}

public final class PUITimelineView: NSView {

    typealias AnnotationTuple = (annotation: PUITimelineAnnotation, layer: PUIAnnotationLayer)

    private let log = OSLog(subsystem: "PlayerUI", category: "PUITimelineView")

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

    public var playbackProgress: Double = 0 {
        didSet {
            layoutPlaybackLayer()
        }
    }

    public var annotations: [PUITimelineAnnotation] = [] {
        didSet {
            if isEditingAnnotation {
                // This isn't supported because the entire annotation UI gets rebuilt
                os_log("Changing the annotations during an edit is unsupported", log: log, type: .error)
            }
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
        static let textSize: CGFloat = 14.0
        static let timePreviewTextSize: CGFloat = 18.0
        static let timePreviewYOffset: CGFloat = -32.0
        static let timePreviewLeftOfMouseWidthMultiplier: CGFloat = 0.5
        static let timePreviewRightOfMouseWidthMultiplier: CGFloat = 0.7
    }

    private var borderLayer: PUIBoringLayer!
    private var bufferingProgressLayer: PUIBufferLayer!
    private var playbackProgressLayer: PUIBoringLayer!
    private var seekProgressLayer: PUIBoringLayer!
    private var timePreviewLayer: PUIBoringTextLayer!

    private func buildUI() {
        wantsLayer = true
        layer = PUIBoringLayer()
        layer?.masksToBounds = false

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

        seekProgressLayer = PUIBoringLayer()
        seekProgressLayer.backgroundColor = NSColor.seekProgress.cgColor
        seekProgressLayer.frame = bounds
        seekProgressLayer.cornerRadius = Metrics.cornerRadius
        seekProgressLayer.masksToBounds = true

        layer?.addSublayer(seekProgressLayer)

        // Time Preview

        timePreviewLayer = PUIBoringTextLayer()
        timePreviewLayer.masksToBounds = true

        layer?.addSublayer(timePreviewLayer)
    }

    public func resetUI() {
        playbackProgress = 0
        annotations = []
        loadedSegments = []
        mediaDuration = 0 // Must be last
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

        let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .mouseMoved, .activeInActiveApp]
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
        updateTimePreview(with: event)
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
        seekProgressLayer.frame = ghostRect
    }

    private func updateTimePreview(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let previewTimestampString = attributedString(for: makeTimestamp(for: point), ofSize: Metrics.timePreviewTextSize)

        timePreviewLayer.opacity = 1
        timePreviewLayer.string = previewTimestampString
        timePreviewLayer.contentsScale = window?.screen?.backingScaleFactor ?? 1

        var previewRect = timePreviewLayer.frame
        if let textLayerContents = timePreviewLayer.string as? NSAttributedString {
            let s = textLayerContents.size()
            previewRect.size = CGSize(width: ceil(s.width), height: ceil(s.height))
        }
        previewRect.origin = CGPoint(x: point.x - previewRect.width / 2, y: Metrics.timePreviewYOffset)

        timePreviewLayer.frame = previewRect
    }

    public override var mouseDownCanMoveWindow: Bool {
        // swiftlint:disable:next unused_setter_value
        set { }
        get { return false }
    }

    public override func mouseDown(with event: NSEvent) {
        guard hasValidMediaDuration else { return }
        if let targetAnnotation = hoveredAnnotation {
            mouseDown(targetAnnotation.annotation, layer: targetAnnotation.layer, originalEvent: event)
            return
        }

        selectedAnnotation = nil
        delegate?.timelineDidSelectAnnotation(nil)
        unhighlightCurrentHoveredAnnotationIfNeeded()

        var startedInteractiveSeek = false

        window?.trackEvents(matching: [.pressure, .leftMouseUp, .leftMouseDragged, .tabletPoint], timeout: NSEvent.foreverDuration, mode: .eventTracking) { event, stop in
            let point = self.convert((event?.locationInWindow)!, from: nil)
            let progress = Double(point.x / self.bounds.width)

            switch event?.type {
            case .leftMouseUp?:
                if startedInteractiveSeek {
                    self.viewDelegate?.timelineViewDidFinishInteractiveSeek()
                } else {
                    // single click seek
                    self.viewDelegate?.timelineViewDidSeek(to: progress)
                }

                stop.pointee = true
            case .pressure?, .tabletPoint?:
                switch event?.touchForce {
                case .forceTouch?:
                    guard self.hasValidMediaDuration else {
                        stop.pointee = true
                        return
                    }

                    let timestamp = self.mediaDuration * progress

                    os_log("Force touch at %{public}f", log: log, type: .debug, timestamp)

                    self.viewDelegate?.timelineDidReceiveForceTouch(at: timestamp)

                    stop.pointee = true
                default: break
                }
            case .leftMouseDragged?:
                if !startedInteractiveSeek {
                    startedInteractiveSeek = true
                    self.viewDelegate?.timelineViewWillBeginInteractiveSeek()
                }

                self.viewDelegate?.timelineViewDidSeek(to: progress)

                self.seekProgressLayer.opacity = 0
            default: break
            }
        }

        NSApp.discardEvents(matching: .leftMouseDown, before: nil)
    }

    private func reactToMouse() {
        if hasMouseInside {
            borderLayer.animate { borderLayer.borderColor = NSColor.highlightedPlayerBorder.cgColor }
            seekProgressLayer.animate { seekProgressLayer.opacity = 1 }
            timePreviewLayer.animateVisible()
        } else {
            borderLayer.animate { borderLayer.borderColor = NSColor.playerBorder.cgColor }
            seekProgressLayer.animate { seekProgressLayer.opacity = 0 }
            timePreviewLayer.animateInvisible()
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

    private func attributedString(for timestamp: Double, ofSize size: CGFloat = Metrics.textSize) -> NSAttributedString {
        let pStyle = NSMutableParagraphStyle()
        pStyle.alignment = .center

        let timeTextAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: size, weight: .medium),
            .foregroundColor: NSColor.playerHighlight,
            .paragraphStyle: pStyle
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

    private var hoveredAnnotation: AnnotationTuple?
    private var selectedAnnotation: AnnotationTuple? {
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

    private func annotationUnderMouse(with event: NSEvent, diameter: CGFloat = Metrics.annotationBubbleDiameter) -> AnnotationTuple? {
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
        guard let annotationUnderMouse = annotationUnderMouse(with: event) else {
            unhighlightCurrentHoveredAnnotationIfNeeded()

            return
        }

        hoveredAnnotation = annotationUnderMouse

        mouseOver(annotationUnderMouse.annotation, layer: annotationUnderMouse.layer)
    }

    private func unhighlightCurrentHoveredAnnotationIfNeeded() {
        guard let (ha, hal) = hoveredAnnotation else { return }

        if let (sa, _) = selectedAnnotation {
            guard sa.identifier != ha.identifier else { return }
        }

        mouseOut(ha, layer: hal)

        hoveredAnnotation = nil
    }

    private func unhighlight(annotationTuple: AnnotationTuple?) {
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
        layer.attachedLayer.animateVisible()

        timePreviewLayer.opacity = 0
    }

    private func mouseOut(_ annotation: PUITimelineAnnotation, layer: PUIAnnotationLayer) {
        CATransaction.begin()
        defer { CATransaction.commit() }

        layer.animate {
            layer.transform = CATransform3DIdentity
            layer.borderWidth = 0
            layer.attachedLayer.opacity = 0
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
                    NSCursor.disappearingItem.push()
                    layer.attachedLayer.animateInvisible()
                } else if oldValue == .delete && mode != .delete {
                    NSCursor.pop()
                    layer.attachedLayer.animateVisible()
                } else if mode == .none && cancelled {
                    layer.animate { layer.position = originalPosition }
                    updateAnnotationTextLayer(with: originalTimestampString)
                }
            }
        }

        var isSnappingBack = false {
            didSet {
                if !oldValue && isSnappingBack {
                    // give haptic feedback when snapping the annotation back to its original position
                    NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
                }
            }
        }

        func updateAnnotationTextLayer(at point: CGPoint) {
            let timestamp = makeTimestamp(for: point)

            layer.attachedLayer.string = attributedString(for: timestamp)
        }

        func updateAnnotationTextLayer(with string: Any?) {
            guard let str = string else { return }

            layer.attachedLayer.string = str
        }

        window?.trackEvents(matching: [.leftMouseUp, .leftMouseDragged, .keyUp], timeout: NSEvent.foreverDuration, mode: .eventTracking) { event, stop in
            let point = self.convert((event?.locationInWindow)!, from: nil)

            switch event?.type {
            case .leftMouseUp?:
                switch mode {
                case .delete:
                    cancelled = false

                    // poof
                    __NSShowAnimationEffect(.poof, NSEvent.mouseLocation, .zero, nil, nil, nil)

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
                    if !isSnappingBack {
                        self.selectedAnnotation = (annotation, layer)
                        self.delegate?.timelineDidSelectAnnotation(annotation)
                    }
                }

                mode = .none
                self.hoveredAnnotation = nil
                updateAnnotationTextLayer(at: point)

                stop.pointee = true
            case .leftMouseDragged?:
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

                    isSnappingBack = false
                } else if abs(horizontalDiff) > Metrics.annotationDragThresholdHorizontal && canMove {
                    newPosition.y = originalPosition.y
                    newPosition.x = point.x
                    mode = .move

                    updateAnnotationTextLayer(at: point)

                    isSnappingBack = false
                } else {
                    layer.position = originalPosition
                    mode = .none

                    isSnappingBack = true
                }

                if mode != .none {
                    layer.position = newPosition
                }
            case .keyUp?:
                // cancel with ESC
                if event?.keyCode == 53 {
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
        controller.view.autoresizingMask = [.width, .height]
        contentView.addSubview(controller.view)

        let layerRect = convertFromLayer(annotationLayer.frame)
        let windowRect = convert(layerRect, to: nil)
        guard var screenRect = window?.convertToScreen(windowRect) else { return }

        screenRect.origin.y += 56
        screenRect.origin.x -= round((contentView.bounds.width / 2) - annotationLayer.bounds.width)

        annotationWindow.alphaValue = 0

        window?.addChildWindow(annotationWindow, ordered: .above)
        annotationWindow.setFrameOrigin(screenRect.origin)
        annotationWindow.makeKeyAndOrderFront(nil)

        annotationWindow.animator().alphaValue = 1

        enum AnnotationKeyCommand: UInt16 {
            case escape = 53
            case enter = 36
        }

        annotationCommandsMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyUp, .keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown]) { event in

            func handleKeyUp(command: AnnotationKeyCommand) {
                switch command {
                case .enter:
                    if event.modifierFlags.contains(.command) {
                        fallthrough
                    }
                case .escape:
                    self.selectedAnnotation = nil
                }
            }

            if [.keyDown, .keyUp].contains(event.type),
                let command = AnnotationKeyCommand(rawValue: event.keyCode) {

                switch event.type {
                case .keyDown where command == .escape:
                    // Prevent the bell
                    return nil
                case .keyDown where command == .enter && event.modifierFlags.contains(.command):
                    return nil
                case .keyUp:
                    handleKeyUp(command: command)
                default: ()
                }
            } else if let window = event.window, window != annotationWindow {
                self.selectedAnnotation = nil
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
        NSAnimationContext.current.completionHandler = {
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
