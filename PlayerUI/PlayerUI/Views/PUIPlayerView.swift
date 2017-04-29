//
//  PUIPlayerView.swift
//  PlayerProto
//
//  Created by Guilherme Rambo on 29/04/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
import AVFoundation

public final class PUIPlayerView: NSView {
    
    // MARK: - Public API
    
    public var timelineDelegate: PUITimelineDelegate? {
        get {
            return timelineView.delegate
        }
        set {
            timelineView.delegate = newValue
        }
    }
    
    public var player: AVPlayer {
        didSet {
            teardown(player: oldValue)
            
            setupPlayer()
        }
    }
    
    public init(player: AVPlayer) {
        self.player = player
        
        super.init(frame: .zero)
        
        self.wantsLayer = true
        self.layer = PUIBoringLayer()
        self.layer?.backgroundColor = NSColor.black.cgColor
        self.layerUsesCoreImageFilters = true
        
        setupPlayer()
        setupControls()
    }
    
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public var isPlaying: Bool {
        return !player.rate.isZero
    }
    
    // MARK: - Private API
    
    private var playerTimeObserver: Any?
    
    fileprivate var asset: AVAsset? {
        return player.currentItem?.asset
    }
    
    private var playerLayer = PUIBoringPlayerLayer()
    
    private func setupPlayer() {
        playerLayer.player = player
        playerLayer.frame = bounds
        playerLayer.videoGravity = AVLayerVideoGravityResizeAspect
        
        layer?.addSublayer(playerLayer)
        
        player.addObserver(self, forKeyPath: #keyPath(AVPlayer.status), options: [.initial, .new], context: nil)
        
        asset?.loadValuesAsynchronously(forKeys: ["tracks"], completionHandler: metadataBecameAvailable)
        
        playerTimeObserver = player.addPeriodicTimeObserver(forInterval: CMTimeMakeWithSeconds(0.5, 9000), queue: DispatchQueue.main, using: playerTimeDidChange)
    }
    
    private func teardown(player oldValue: AVPlayer) {
        if let observer = playerTimeObserver {
            oldValue.removeTimeObserver(observer)
        }
        
        oldValue.removeObserver(self, forKeyPath: #keyPath(AVPlayer.status))
        
        oldValue.pause()
        oldValue.cancelPendingPrerolls()
    }
    
    public override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == #keyPath(AVPlayer.status) {
            playerStatusChanged()
        } else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }
    
    private func playerStatusChanged() {
        // TODO: reflect important player statuses
    }
    
    private func metadataBecameAvailable() {
        guard let duration = asset?.duration else { return }
        
        timelineView.mediaDuration = Double(CMTimeGetSeconds(duration))
    }
    
    private func playerTimeDidChange(time: CMTime) {
        guard let duration = asset?.duration else { return }
        
        let progress = Double(CMTimeGetSeconds(time) / CMTimeGetSeconds(duration))
        timelineView.playbackProgress = progress
    }
    
    public override func layout() {
        super.layout()
        
        playerLayer.frame = bounds
    }
    
    deinit {
        teardown(player: player)
    }
    
    // MARK: Controls
    
    fileprivate var wasPlayingBeforeStartingInteractiveSeek = false
    
    private var controlsContainerView: NSStackView!
    
    private var timelineView: PUITimelineView!
    
    private func setupControls() {
        // Timeline view
        timelineView = PUITimelineView(frame: .zero)
        timelineView.viewDelegate = self
        
        // Main stack view
        controlsContainerView = NSStackView(views: [timelineView])
        controlsContainerView.orientation = .vertical
        controlsContainerView.spacing = 12
        controlsContainerView.distribution = .fill
        controlsContainerView.translatesAutoresizingMaskIntoConstraints = false
        controlsContainerView.wantsLayer = true
        controlsContainerView.layer?.opacity = 0.9
        controlsContainerView.layer?.compositingFilter = "lightenBlendMode"
        
        addSubview(controlsContainerView)
        
        controlsContainerView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12).isActive = true
        controlsContainerView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12).isActive = true
        controlsContainerView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16).isActive = true
    }
    
    // MARK: - Visibility management
    
    fileprivate var canHideControls: Bool {
        guard player.status == .readyToPlay else { return false }
        guard let window = window else { return false }
        
        let windowMouseRect = window.convertFromScreen(NSRect(origin: NSEvent.mouseLocation(), size: CGSize(width: 1, height: 1)))
        let viewMouseRect = convert(windowMouseRect, from: nil)
        
        // don't hide the controls when the mouse is over them
        return !viewMouseRect.intersects(controlsContainerView.frame)
    }
    
    fileprivate var mouseIdleTimer: Timer!
    
    fileprivate func resetMouseIdleTimer(start: Bool = true) {
        if mouseIdleTimer != nil {
            mouseIdleTimer.invalidate()
            mouseIdleTimer = nil
        }
        
        if start {
            mouseIdleTimer = Timer.scheduledTimer(timeInterval: 3.0, target: self, selector: #selector(mouseIdleTimerAction(_:)), userInfo: nil, repeats: false)
        }
    }
    
    @objc fileprivate func mouseIdleTimerAction(_ sender: Timer) {
        guard canHideControls else { return }
        
        NSCursor.hide()
        
        hideControls(animated: true)
    }
    
    private func hideControls(animated: Bool) {
        guard canHideControls else { return }
        
        setControls(opacity: 0, animated: animated)
    }
    
    private func showControls(animated: Bool) {
        NSCursor.unhide()
        
        setControls(opacity: 1, animated: animated)
    }
    
    private func setControls(opacity: CGFloat, animated: Bool) {
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = animated ? 0.4 : 0.0
            self.controlsContainerView.animator().alphaValue = opacity
        }, completionHandler: nil)
    }
    
    public override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        
        resetMouseIdleTimer()
    }
    
    // MARK: - Events
    
    private var mouseTrackingArea: NSTrackingArea!
    
    public override func updateTrackingAreas() {
        super.updateTrackingAreas()
        
        if mouseTrackingArea != nil {
            removeTrackingArea(mouseTrackingArea)
        }
        
        let options: NSTrackingAreaOptions = [.mouseEnteredAndExited, .mouseMoved, .activeAlways, .inVisibleRect]
        mouseTrackingArea = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        
        addTrackingArea(mouseTrackingArea)
    }
    
    public override func mouseEntered(with event: NSEvent) {
        showControls(animated: true)
        resetMouseIdleTimer()
        
        super.mouseExited(with: event)
    }
    
    public override func mouseMoved(with event: NSEvent) {
        showControls(animated: true)
        resetMouseIdleTimer()
        
        super.mouseMoved(with: event)
    }
    
    public override func mouseExited(with event: NSEvent) {
        resetMouseIdleTimer(start: false)
        
        hideControls(animated: true)
        
        super.mouseExited(with: event)
    }
    
    public override func mouseDown(with event: NSEvent) {
        var c = 0
        var doubleClicked = false
        var cancelledByDrag = false
        
        // allow double-click to enter full screen while still allowing single click to play/pause without playing or pausing on double click
        while let e = NSApp.nextEvent(matching: [.leftMouseUp, .leftMouseDragged], until: Date().addingTimeInterval(0.2), inMode: .defaultRunLoopMode, dequeue: true) {
            if e.type == .leftMouseUp {
                c += 1
            } else {
                // if the user drags, we cancel the click interaction
                cancelledByDrag = true
            }
            doubleClicked = c > 1
        }
        
        guard !cancelledByDrag else { return }
        
        if doubleClicked {
            window?.toggleFullScreen(self)
        } else {
            if isPlaying {
                player.pause()
            } else {
                player.play()
            }
        }
        
        super.mouseDown(with: event)
    }
    
}

// MARK: - PUITimelineViewDelegate

extension PUIPlayerView: PUITimelineViewDelegate {
    
    func timelineViewWillBeginInteractiveSeek() {
        wasPlayingBeforeStartingInteractiveSeek = isPlaying
        
        player.pause()
    }
    
    func timelineViewDidSeek(to progress: Double) {
        guard let duration = asset?.duration else { return }
        
        let targetTime = progress * Double(CMTimeGetSeconds(duration))
        let time = CMTimeMakeWithSeconds(targetTime, duration.timescale)
        
        player.seek(to: time)
    }
    
    func timelineViewDidFinishInteractiveSeek() {
        if wasPlayingBeforeStartingInteractiveSeek {
            player.play()
        }
    }
    
}
