//
//  PUITimelineView.swift
//  PlayerProto
//
//  Created by Guilherme Rambo on 28/04/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa

public protocol PUITimelineDelegate: class {
    
    func viewForTimeline(_ annotation: PUITimelineAnnotation) -> NSView?
    func timelineDidReceiveForceTouch(at timestamp: Double)
    
}

public protocol PUITimelineAnnotation {
    var identifier: String { get }
    var timestamp: Double { get }
}

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
            
        }
    }
    
    public var mediaDuration: Double = 0
    
    // MARK: - Private API
    
    weak var viewDelegate: PUITimelineViewDelegate?
    
    var loadedSegments = Set<PUIBufferSegment>() {
        didSet {
            bufferingProgressLayer.segments = loadedSegments
        }
    }
    
    struct Metrics {
        static let cornerRadius: CGFloat = 4
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
    }
    
    private func layoutBufferingLayer() {
        bufferingProgressLayer.frame = bounds
    }
    
    private func layoutPlaybackLayer() {
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
    }
    
    public override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        
        guard hasMouseInside else { return }
        
        self.updateGhostProgress(with: event)
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
    
}
