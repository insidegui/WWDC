//
//  PUITimelineView.swift
//  PlayerProto
//
//  Created by Guilherme Rambo on 28/04/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import SwiftUI
import AVFoundation
import OSLog
import ConfUIFoundation

protocol PUITimelineViewDelegate: AnyObject {

    func timelineViewWillBeginInteractiveSeek()
    func timelineViewDidSeek(to progress: Double)
    func timelineViewDidFinishInteractiveSeek()
    func timelineDidReceiveForceTouch(at timestamp: Double)

}

public final class PUITimelineView: NSView {

    typealias AnnotationTuple = (annotation: PUITimelineAnnotation, layer: PUIAnnotationLayer)

    private let log = Logger(subsystem: "PlayerUI", category: "PUITimelineView")

    // MARK: - Public API

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        buildUI()
    }

    init(adoptLiquidGlass: Bool) {
        super.init(frame: .zero)
        buildUI(adoptLiquidGlass: adoptLiquidGlass)
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        buildUI()
    }

    public override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: Metrics.height)
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
                log.error("Changing the annotations during an edit is unsupported")
            }
            layoutAnnotations()
        }
    }

    @MainActor
    @Invalidating(.layout)
    public var mediaDuration: Double = 0

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
        static let height: CGFloat = 8
        static let annotationMarkerWidth: CGFloat = 14
        static let annotationMarkerHoverScale: CGFloat = 1.3
        static let annotationDragThresholdVertical: CGFloat = 15
        static let annotationDragThresholdHorizontal: CGFloat = 6
        static let textSize: CGFloat = 14.0
        static let floatingLayerTextSize: CGFloat = 15.0
        static let floatingLayerMargin: CGFloat = 8
        static let timePreviewLeftOfMouseWidthMultiplier: CGFloat = 0.5
        static let timePreviewRightOfMouseWidthMultiplier: CGFloat = 0.7
    }

    private var borderLayer: PUIBoringLayer!
    private var bufferingProgressLayer: PUIBufferLayer!
    private var playbackProgressLayer: PUIBoringLayer!
    private var seekProgressLayer: PUIBoringLayer!
    private var annotationsContainerLayer = CALayer()

    private lazy var floatingTimeLayer = PUITimelineFloatingLayer()
    private var floatingModel: PUITimelineFloatingModel?
    private var floatingGlassView: NSView?

    private func buildUI(adoptLiquidGlass: Bool = false) {
        wantsLayer = true
        layer = PUIBoringLayer()
        layer?.masksToBounds = false

        // Main border

        borderLayer = PUIBoringLayer()
        borderLayer.borderColor = NSColor.playerBorder.preferredCGColor(in: .darkAqua)
        borderLayer.borderWidth = 1.0
        borderLayer.frame = bounds

        layer?.addSublayer(borderLayer)

        // Buffering bar

        bufferingProgressLayer = PUIBufferLayer()
        bufferingProgressLayer.frame = bounds
        bufferingProgressLayer.masksToBounds = true

        layer?.addSublayer(bufferingProgressLayer)

        // Playback bar

        playbackProgressLayer = PUIBoringLayer()
        playbackProgressLayer.backgroundColor = NSColor.playerProgress.preferredCGColor(in: .darkAqua)
        playbackProgressLayer.frame = bounds
        playbackProgressLayer.masksToBounds = true

        layer?.addSublayer(playbackProgressLayer)

        // Ghost bar

        seekProgressLayer = PUIBoringLayer()
        seekProgressLayer.backgroundColor = NSColor.seekProgress.preferredCGColor(in: .darkAqua)
        seekProgressLayer.frame = bounds

        layer?.addSublayer(seekProgressLayer)

        // Floating time

        if #available(macOS 26.0, *), adoptLiquidGlass {
            let model = PUITimelineFloatingModel()
            let glassView = NSHostingView(rootView: PUITimelineGlassFloatingView().environment(model))
            floatingGlassView = glassView
            floatingModel = model
            glassView.frame = .zero
            addSubview(glassView)
        } else {
            layer?.addSublayer(floatingTimeLayer)
        }

        // Annotations container

        annotationsContainerLayer.frame = bounds
        annotationsContainerLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        annotationsContainerLayer.masksToBounds = false
        layer?.addSublayer(annotationsContainerLayer)

        #if DEBUG
        setupForPreviewIfNeeded()
        #endif
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

        updateCornerRadii()
        layoutBufferingLayer()
        layoutPlaybackLayer()
        layoutAnnotations(distributeOnly: true)
    }

    private func updateCornerRadii() {
        let radius = bounds.height * 0.5
        seekProgressLayer.cornerRadius = radius
        playbackProgressLayer.cornerRadius = radius
        borderLayer.cornerRadius = radius
        bufferingProgressLayer.cornerRadius = radius
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

    private(set) var hasMouseInside: Bool = false {
        didSet {
            guard hasMouseInside != oldValue else { return }
            
            UILog("🐭 hasMouseInside = \(hasMouseInside)")

            reactToMouse()
        }
    }

    /// Expanded bounds where the mouse cursor should be considered to be inside the timeline view.
    /// The area is expanded in order to make it easier to interact with the small vertical area of the timeline.
    var hoverBounds: CGRect {
        /// Once hovering is established, require a larger distance before disengaging hover.
        let yOffset: CGFloat = hasMouseInside ? -16 : -8
        return bounds.insetBy(dx: 0, dy: yOffset)
    }

    public override func mouseEntered(with event: NSEvent) {
        hasMouseInside = true
    }

    public override func mouseExited(with event: NSEvent) {
        hasMouseInside = false

        unhighlightCurrentHoveredAnnotationIfNeeded()
    }

    public override func mouseMoved(with event: NSEvent) {
        guard hasMouseInside else { return }

        updateGhostProgress(with: event)
        updateFloatingTime(with: event)
        trackMouseAgainstAnnotations(with: event)
    }

    private func updateGhostProgress(with event: NSEvent) {
        guard selectedAnnotation == nil else { return }

        let point = convert(event.locationInWindow, from: nil)
        guard point.x > 0 && point.x < bounds.width else {
            return
        }

        let ghostWidth = point.x
        var ghostRect = bounds
        ghostRect.size.width = ghostWidth
        seekProgressLayer.opacity = 1
        seekProgressLayer.frame = ghostRect
    }

    private func updateFloatingTime(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        
        updateFloatingTime(with: point)
    }

    private func updateFloatingTime(with point: CGPoint, ignoreAnimationHover: Bool = false) {
        /// If there's no annotation currently being edited, then the user can prevent the time preview from snapping to the annotation by holding down Command.
        let annotationIgnoredByUser = selectedAnnotation == nil && NSEvent.modifierFlags.contains(.command)
        /// `true` if the floating time should be updated based on the current hovered or selected annotation.
        let useAnnotationData = !(ignoreAnimationHover || annotationIgnoredByUser)
        /// Will be the annotation tuple for the selected annotation or the hovered annotation.
        let targetAnnotation: AnnotationTuple? = useAnnotationData ? selectedAnnotation ?? hoveredAnnotation : nil

        let timestamp = targetAnnotation?.annotation.timestamp ?? makeTimestamp(for: point)
        let position: CGPoint = targetAnnotation?.layer.position ?? point

        let text = PUITimelineFloatingLayer.attributedString(for: timestamp, font: .monospacedDigitSystemFont(ofSize: Metrics.floatingLayerTextSize, weight: .medium))

        floatingTimeLayer.show(animated: false)
        floatingTimeLayer.attributedText = text
        floatingModel?.attributedText = text
        floatingModel?.show(animated: false)

        var floatingTimeRect = floatingTimeLayer.frame

        floatingTimeRect.origin = CGPoint(
            x: position.x - floatingTimeRect.width / 2,
            y: bounds.minY - floatingTimeRect.height - Metrics.floatingLayerMargin
        )

        floatingTimeLayer.frame = floatingTimeRect
        floatingGlassView?.frame = floatingTimeRect
    }

    public override var mouseDownCanMoveWindow: Bool {
        get { return false }
        set { }
    }

    public override func mouseDown(with event: NSEvent) {
        guard hasValidMediaDuration else { return }
       
        if let targetAnnotation = hoveredAnnotation {
            mouseDown(targetAnnotation.annotation, layer: targetAnnotation.layer, originalEvent: event)
            return
        }

        let isDeselectingAnnotation = selectedAnnotation != nil

        selectedAnnotation = nil
        delegate?.timelineDidSelectAnnotation(nil)
        unhighlightCurrentHoveredAnnotationIfNeeded()

        /// Clicking outside selected annotation should only deselect that annotation and not perform a seek.
        guard !isDeselectingAnnotation else { return }

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

                    log.debug("Force touch at \(timestamp, privacy: .public)")

                    self.viewDelegate?.timelineDidReceiveForceTouch(at: timestamp)

                    stop.pointee = true
                default: break
                }
            case .leftMouseDragged?:
                if !startedInteractiveSeek {
                    floatingTimeLayer.hide()
                    floatingModel?.hide()
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
            borderLayer.animate { borderLayer.borderColor = NSColor.highlightedPlayerBorder.preferredCGColor(in: .darkAqua) }
            seekProgressLayer.animate { seekProgressLayer.opacity = 1 }
            floatingTimeLayer.show()
            floatingModel?.show()
        } else {
            borderLayer.animate { borderLayer.borderColor = NSColor.playerBorder.preferredCGColor(in: .darkAqua) }
            seekProgressLayer.animate { seekProgressLayer.opacity = 0 }
            if selectedAnnotation == nil {
                floatingTimeLayer.hide()
                floatingModel?.hide()
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

        annotationLayers = annotations.map { annotation in
            let l = PUIAnnotationLayer()

            l.name = annotation.identifier
            l.zPosition = 999

            return l
        }

        annotations.forEach { annotation in
            guard let l = annotationLayers.first(where: { $0.name == annotation.identifier }) else { return }

            layoutAnnotationLayer(l, for: annotation, with: Metrics.annotationMarkerWidth)
        }

        annotationLayers.forEach({ annotationsContainerLayer.addSublayer($0) })
    }

    private func layoutAnnotationLayer(_ layer: PUIBoringLayer, for annotation: PUITimelineAnnotation, with diameter: CGFloat, animated: Bool = false) {
        guard hasValidMediaDuration else { return }

        let x: CGFloat = (CGFloat(annotation.timestamp / mediaDuration) * bounds.width) - (diameter / 2)
        let y: CGFloat = -1

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

    private var hoveredAnnotation: AnnotationTuple? {
        didSet {
            if oldValue?.layer !== selectedAnnotation?.layer {
                oldValue?.layer.isHighlighted = false
            }
        }
    }

    private var selectedAnnotation: AnnotationTuple? {
        didSet {
            unhighlight(annotationTuple: oldValue)

            if selectedAnnotation != nil {
                seekProgressLayer.opacity = 0
                showAnnotationWindow()
                hoveredAnnotation = nil
            } else if oldValue != nil {
                unhighlightCurrentHoveredAnnotationIfNeeded()
                hideAnnotationWindow()
            }
        }
    }

    private func annotationUnderMouse(with event: NSEvent, diameter: CGFloat = Metrics.annotationMarkerWidth) -> AnnotationTuple? {
        let point = convert(event.locationInWindow, from: nil)

        guard let hitAnnotationLayer = annotationsContainerLayer.hitTest(point)?.superlayer as? PUIAnnotationLayer else { return nil }

        guard let name = hitAnnotationLayer.name else { return nil }

        guard let annotation = annotations.first(where: { $0.identifier == name }) else { return nil }

        return (annotation: annotation, layer: hitAnnotationLayer)
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

        layer.isHighlighted = true

        floatingTimeLayer.show()
        floatingModel?.show()
    }

    private func mouseOut(_ annotation: PUITimelineAnnotation, layer: PUIAnnotationLayer) {
        CATransaction.begin()
        defer { CATransaction.commit() }

        layer.isHighlighted = false

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

        var cancelled = true

        let canDelete = delegate?.timelineCanDeleteAnnotation(annotation) ?? false
        let canMove = delegate?.timelineCanMoveAnnotation(annotation) ?? false

        var mode: AnnotationDragMode = .none {
            didSet {
                if oldValue != .delete && mode == .delete {
                    NSCursor.disappearingItem.push()
                } else if oldValue == .delete && mode != .delete {
                    NSCursor.pop()
                } else if mode == .none && cancelled {
                    layer.animate { layer.position = originalPosition }
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

                    isSnappingBack = false
                } else {
                    layer.position = originalPosition
                    mode = .none

                    isSnappingBack = true
                }

                if mode != .none {
                    layer.position = newPosition
                }

                updateFloatingTime(with: layer.position, ignoreAnimationHover: true)
                
                if mode == .delete {
                    floatingTimeLayer.hide()
                    floatingModel?.hide()
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

        floatingTimeLayer.show()
        floatingModel?.show()
        updateFloatingTime(with: annotationLayer.position)

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
        UILog(#function)

        floatingTimeLayer.hide()
        floatingModel?.hide()

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

#if DEBUG
private extension PUITimelineView {
    private static let previewDelegate = PreviewTimelineDelegate()

    func setupForPreviewIfNeeded() {
        guard ProcessInfo.isSwiftUIPreview else { return }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            self.deferredSetupPreviewContent(
                forceTimePreviewVisible: false,
                addAnnotations: true
            )
        }
    }

    private func deferredSetupPreviewContent(forceTimePreviewVisible: Bool, addAnnotations: Bool) {
        if forceTimePreviewVisible {
            self.updateFloatingTime(with: CGPoint(x: 100, y: 0))
            self.floatingTimeLayer.show()
            floatingModel?.show()
        }

        if addAnnotations {
            self.delegate = Self.previewDelegate

            self.annotations = [
                FakePreviewAnnotation(timestamp: self.mediaDuration * 0.13),
                FakePreviewAnnotation(timestamp: self.mediaDuration * 0.16),
                FakePreviewAnnotation(timestamp: self.mediaDuration * 0.4),
                FakePreviewAnnotation(timestamp: self.mediaDuration * 0.65),
                FakePreviewAnnotation(timestamp: self.mediaDuration * 0.85)
            ]
        }
    }
}

private final class PreviewTimelineDelegate: PUITimelineDelegate {
    func viewControllerForTimelineAnnotation(_ annotation: any PUITimelineAnnotation) -> NSViewController? { nil }

    func timelineDidHighlightAnnotation(_ annotation: (any PUITimelineAnnotation)?) { }

    func timelineDidSelectAnnotation(_ annotation: (any PUITimelineAnnotation)?) { }

    func timelineCanDeleteAnnotation(_ annotation: any PUITimelineAnnotation) -> Bool { true }

    func timelineCanMoveAnnotation(_ annotation: any PUITimelineAnnotation) -> Bool { true }

    func timelineDidMoveAnnotation(_ annotation: any PUITimelineAnnotation, to timestamp: Double) { }

    func timelineDidDeleteAnnotation(_ annotation: any PUITimelineAnnotation) { }
}

private struct FakePreviewAnnotation: PUITimelineAnnotation {
    var identifier: String = UUID().uuidString
    var timestamp: Double
    var isValid: Bool = true
    var isEmpty: Bool = false
}

struct PUITimelineView_Previews: PreviewProvider {
    static var previews: some View { PUIPlayerView_Previews.previews }
}
#endif
