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
    
    public var togglesPlaybackOnSingleClick: Bool = false
    
    public var annotations: [PUITimelineAnnotation] {
        get {
            return sortedAnnotations
        }
        set {
            self.sortedAnnotations = newValue.sorted(by: { $0.timestamp < $1.timestamp })
            
            timelineView.annotations = sortedAnnotations
        }
    }
    
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
        
        setupPlayer()
        setupControls()
    }
    
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public var isPlaying: Bool {
        return !player.rate.isZero
    }
    
    public var currentTimestamp: Double {
        return Double(CMTimeGetSeconds(player.currentTime()))
    }
    
    public var firstAnnotationBeforeCurrentTime: PUITimelineAnnotation? {
        return annotations.filter({ $0.timestamp + 1 < currentTimestamp }).last
    }
    
    public var firstAnnotationAfterCurrentTime: PUITimelineAnnotation? {
        return annotations.filter({ $0.timestamp > currentTimestamp + 1 }).first
    }
    
    public func seek(to annotation: PUITimelineAnnotation) {
        let time = CMTimeMakeWithSeconds(Float64(annotation.timestamp), 9000)
        
        player.seek(to: time)
    }
    
    public var playbackSpeed: PUIPlaybackSpeed = .normal {
        didSet {
            if isPlaying { player.rate = playbackSpeed.rawValue }
            
            speedButton.image = playbackSpeed.icon
        }
    }
    
    // MARK: - Private API
    
    private var sortedAnnotations: [PUITimelineAnnotation] = [] {
        didSet {
            updateAnnotationsState()
        }
    }
    
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
        player.addObserver(self, forKeyPath: #keyPath(AVPlayer.rate), options: [.initial, .new], context: nil)
        player.addObserver(self, forKeyPath: #keyPath(AVPlayer.currentItem.loadedTimeRanges), options: [.initial, .new], context: nil)
        
        asset?.loadValuesAsynchronously(forKeys: ["tracks"], completionHandler: metadataBecameAvailable)
        
        playerTimeObserver = player.addPeriodicTimeObserver(forInterval: CMTimeMakeWithSeconds(0.5, 9000), queue: DispatchQueue.main, using: playerTimeDidChange)
    }
    
    private func teardown(player oldValue: AVPlayer) {
        if let observer = playerTimeObserver {
            oldValue.removeTimeObserver(observer)
        }
        
        oldValue.removeObserver(self, forKeyPath: #keyPath(AVPlayer.status))
        oldValue.removeObserver(self, forKeyPath: #keyPath(AVPlayer.rate))
        oldValue.removeObserver(self, forKeyPath: #keyPath(AVPlayer.currentItem.loadedTimeRanges))
        
        oldValue.pause()
        oldValue.cancelPendingPrerolls()
    }
    
    public override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        DispatchQueue.main.async {
            if keyPath == #keyPath(AVPlayer.status) {
                self.playerStatusChanged()
            } else if keyPath == #keyPath(AVPlayer.currentItem.loadedTimeRanges) {
                self.updateBufferedSegments()
            } else if keyPath == #keyPath(AVPlayer.rate) {
                self.updatePlayingState()
            } else {
                super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
            }
        }
    }
    
    private func updateBufferedSegments() {
        guard let loadedRanges = player.currentItem?.loadedTimeRanges else { return }
        guard let durationTime = player.currentItem?.duration else { return }
        
        let duration = Double(CMTimeGetSeconds(durationTime))
        
        let segments = loadedRanges.map { value -> PUIBufferSegment in
            let range = value.timeRangeValue
            let startTime = Double(CMTimeGetSeconds(range.start))
            let segmentDuration = Double(CMTimeGetSeconds(range.duration))
            
            return PUIBufferSegment(start: startTime / duration, duration: segmentDuration / duration)
        }
        
        timelineView.loadedSegments = Set<PUIBufferSegment>(segments)
    }
    
    private func updateAnnotationsState() {
        let canGoBack = firstAnnotationBeforeCurrentTime != nil
        let canGoForward = firstAnnotationAfterCurrentTime != nil
        
        previousAnnotationButton.isEnabled = canGoBack
        nextAnnotationButton.isEnabled = canGoForward
    }
    
    private func updatePlayingState() {
        if isPlaying {
            playButton.image = .PUIPause
        } else {
            playButton.image = .PUIPlay
        }
    }
    
    private func playerStatusChanged() {
        switch player.status {
        case .readyToPlay:
            self.updateTimeLabels()
        default: break
        }
    }
    
    private func metadataBecameAvailable() {
        DispatchQueue.main.async {
            guard let duration = self.asset?.duration else { return }
            
            self.timelineView.mediaDuration = Double(CMTimeGetSeconds(duration))
        }
    }
    
    private func playerTimeDidChange(time: CMTime) {
        DispatchQueue.main.async {
            guard self.player.hasValidMediaDuration else { return }
            guard let duration = self.asset?.duration else { return }
            
            let progress = Double(CMTimeGetSeconds(time) / CMTimeGetSeconds(duration))
            self.timelineView.playbackProgress = progress
            
            self.updateAnnotationsState()
            self.updateTimeLabels()
        }
    }
    
    private func updateTimeLabels() {
        guard self.player.hasValidMediaDuration else { return }
        guard let duration = self.asset?.duration else { return }
        
        let time = player.currentTime()
        
        self.elapsedTimeLabel.stringValue = String(time: time) ?? ""
        
        let remainingTime = CMTimeSubtract(time, duration)
        self.remainingTimeLabel.stringValue = String(time: remainingTime) ?? ""
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
    
    private var controlsVisualEffectView: NSVisualEffectView!
    
    private var timeLabelsContainerView: NSStackView!
    private var controlsContainerView: NSStackView!
    private var volumeControlsContainerView: NSStackView!
    private var centerButtonsContainerView: NSStackView!
    
    private var timelineView: PUITimelineView!
    
    private lazy var elapsedTimeLabel: NSTextField = {
        let l = NSTextField(labelWithString: "00:00:00")
        
        l.alignment = .left
        l.font = NSFont.systemFont(ofSize: 14, weight: NSFontWeightMedium)
        l.textColor = .timeLabel
        
        return l
    }()
    
    private lazy var remainingTimeLabel: NSTextField = {
        let l = NSTextField(labelWithString: "-00:00:00")
        
        l.alignment = .right
        l.font = NSFont.systemFont(ofSize: 14, weight: NSFontWeightMedium)
        l.textColor = .timeLabel
        
        return l
    }()
    
    private lazy var volumeButton: PUIButton = {
        let b = PUIButton(frame: .zero)
        
        b.image = .PUIVolume
        b.target = self
        b.action = #selector(toggleMute(_:))
        
        return b
    }()
    
    private lazy var volumeSlider: PUISlider = {
        let s = PUISlider(frame: .zero)
        
        s.widthAnchor.constraint(equalToConstant: 88).isActive = true
        s.isContinuous = true
        s.target = self
        s.minValue = 0
        s.maxValue = 1
        s.action = #selector(volumeSliderAction(_:))
        
        return s
    }()
    
    private lazy var subtitlesButton: PUIButton = {
        let b = PUIButton(frame: .zero)
        
        b.image = .PUISubtitles
        b.target = self
        b.action = #selector(showSubtitlesMenu(_:))
        
        return b
    }()
    
    private lazy var playButton: PUIButton = {
        let b = PUIButton(frame: .zero)
        
        b.image = .PUIPlay
        b.target = self
        b.action = #selector(togglePlaying(_:))
        
        return b
    }()
    
    private lazy var previousAnnotationButton: PUIButton = {
        let b = PUIButton(frame: .zero)
        
        b.image = .PUIPreviousBookmark
        b.target = self
        b.action = #selector(previousAnnotation(_:))
        
        return b
    }()
    
    private lazy var nextAnnotationButton: PUIButton = {
        let b = PUIButton(frame: .zero)
        
        b.image = .PUINextBookmark
        b.target = self
        b.action = #selector(nextAnnotation(_:))
        
        return b
    }()
    
    private lazy var backButton: PUIButton = {
        let b = PUIButton(frame: .zero)
        
        b.image = .PUIBack30s
        b.target = self
        b.action = #selector(goBackInTime(_:))
        
        return b
    }()
    
    private lazy var forwardButton: PUIButton = {
        let b = PUIButton(frame: .zero)
        
        b.image = .PUIForward30s
        b.target = self
        b.action = #selector(goForwardInTime(_:))
        
        return b
    }()
    
    private lazy var speedButton: PUIButton = {
        let b = PUIButton(frame: .zero)
        
        b.image = .PUISpeedOne
        b.target = self
        b.action = #selector(toggleSpeed(_:))
        
        return b
    }()
    
    private lazy var addAnnotationButton: PUIButton = {
        let b = PUIButton(frame: .zero)
        
        b.image = .PUIBookmark
        b.target = self
        b.action = #selector(addAnnotation(_:))
        
        return b
    }()
    
    private lazy var pipButton: PUIButton = {
        let b = PUIButton(frame: .zero)
        
        b.image = .PUIPictureInPicture
        b.target = self
        b.action = #selector(togglePip(_:))
        
        return b
    }()
    
    private func setupControls() {
        // VFX view
        controlsVisualEffectView = NSVisualEffectView(frame: bounds)
        controlsVisualEffectView.translatesAutoresizingMaskIntoConstraints = false
        controlsVisualEffectView.material = .ultraDark
        controlsVisualEffectView.appearance = NSAppearance(named: NSAppearanceNameVibrantDark)
        controlsVisualEffectView.blendingMode = .withinWindow
        controlsVisualEffectView.wantsLayer = true
        controlsVisualEffectView.state = .active
        
        // Time labels
        timeLabelsContainerView = NSStackView(views: [elapsedTimeLabel, remainingTimeLabel])
        timeLabelsContainerView.distribution = .fillEqually
        timeLabelsContainerView.orientation = .horizontal
        timeLabelsContainerView.alignment = .centerY
        
        // Timeline view
        timelineView = PUITimelineView(frame: .zero)
        timelineView.viewDelegate = self
        
        // Volume controls
        volumeControlsContainerView = NSStackView(views: [volumeButton, volumeSlider])
        
        volumeControlsContainerView.orientation = .horizontal
        volumeControlsContainerView.spacing = 6
        volumeControlsContainerView.alignment = .centerY
        
        // Center Buttons
        centerButtonsContainerView = NSStackView(frame: bounds)
        
        // Leading controls (volume, subtitles)
        centerButtonsContainerView.addView(volumeButton, in: .leading)
        centerButtonsContainerView.addView(volumeSlider, in: .leading)
        centerButtonsContainerView.addView(subtitlesButton, in: .leading)
        
        centerButtonsContainerView.setCustomSpacing(6, after: volumeButton)
        
        // Center controls (play, annotations, forward, backward)
        centerButtonsContainerView.addView(backButton, in: .center)
        centerButtonsContainerView.addView(previousAnnotationButton, in: .center)
        centerButtonsContainerView.addView(playButton, in: .center)
        centerButtonsContainerView.addView(nextAnnotationButton, in: .center)
        centerButtonsContainerView.addView(forwardButton, in: .center)
        
        // Trailing controls (speed, add annotation, pip)
        centerButtonsContainerView.addView(speedButton, in: .trailing)
        centerButtonsContainerView.addView(addAnnotationButton, in: .trailing)
        centerButtonsContainerView.addView(pipButton, in: .trailing)
        
        centerButtonsContainerView.orientation = .horizontal
        centerButtonsContainerView.spacing = 24
        centerButtonsContainerView.distribution = .gravityAreas
        centerButtonsContainerView.alignment = .centerY
        
        // Visibility priorities
        centerButtonsContainerView.setVisibilityPriority(NSStackViewVisibilityPriorityDetachOnlyIfNecessary, for: volumeButton)
        centerButtonsContainerView.setVisibilityPriority(NSStackViewVisibilityPriorityDetachOnlyIfNecessary, for: volumeSlider)
        centerButtonsContainerView.setVisibilityPriority(NSStackViewVisibilityPriorityDetachOnlyIfNecessary, for: subtitlesButton)
        centerButtonsContainerView.setVisibilityPriority(NSStackViewVisibilityPriorityDetachOnlyIfNecessary, for: backButton)
        centerButtonsContainerView.setVisibilityPriority(NSStackViewVisibilityPriorityDetachOnlyIfNecessary, for: previousAnnotationButton)
        centerButtonsContainerView.setVisibilityPriority(NSStackViewVisibilityPriorityMustHold, for: playButton)
        centerButtonsContainerView.setVisibilityPriority(NSStackViewVisibilityPriorityDetachOnlyIfNecessary, for: forwardButton)
        centerButtonsContainerView.setVisibilityPriority(NSStackViewVisibilityPriorityDetachOnlyIfNecessary, for: nextAnnotationButton)
        centerButtonsContainerView.setVisibilityPriority(NSStackViewVisibilityPriorityDetachOnlyIfNecessary, for: speedButton)
        centerButtonsContainerView.setVisibilityPriority(NSStackViewVisibilityPriorityDetachOnlyIfNecessary, for: addAnnotationButton)
        centerButtonsContainerView.setVisibilityPriority(NSStackViewVisibilityPriorityDetachOnlyIfNecessary, for: pipButton)
        centerButtonsContainerView.setContentCompressionResistancePriority(NSLayoutPriorityDefaultLow, for: .horizontal)
        
        // Main stack view
        controlsContainerView = NSStackView(views: [
            timeLabelsContainerView,
            timelineView,
            centerButtonsContainerView
        ])
        
        controlsContainerView.orientation = .vertical
        controlsContainerView.spacing = 12
        controlsContainerView.distribution = .fill
        controlsContainerView.translatesAutoresizingMaskIntoConstraints = false
        controlsContainerView.wantsLayer = true
        
        controlsVisualEffectView.addSubview(controlsContainerView)
        addSubview(controlsVisualEffectView)
        
        controlsContainerView.leadingAnchor.constraint(equalTo: controlsVisualEffectView.leadingAnchor, constant: 12).isActive = true
        controlsContainerView.trailingAnchor.constraint(equalTo: controlsVisualEffectView.trailingAnchor, constant: -12).isActive = true
        controlsContainerView.topAnchor.constraint(equalTo: controlsVisualEffectView.topAnchor, constant: 12).isActive = true
        controlsContainerView.bottomAnchor.constraint(equalTo: controlsVisualEffectView.bottomAnchor, constant: -12).isActive = true
        
        controlsVisualEffectView.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
        controlsVisualEffectView.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true
        controlsVisualEffectView.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true
        
        timeLabelsContainerView.leadingAnchor.constraint(equalTo: controlsContainerView.leadingAnchor).isActive = true
        timeLabelsContainerView.trailingAnchor.constraint(equalTo: controlsContainerView.trailingAnchor).isActive = true
        
        centerButtonsContainerView.leadingAnchor.constraint(equalTo: controlsContainerView.leadingAnchor).isActive = true
        centerButtonsContainerView.trailingAnchor.constraint(equalTo: controlsContainerView.trailingAnchor).isActive = true
    }
    
    // MARK: - Control actions
    
    @IBAction public func toggleMute(_ sender: Any?) {
        player.isMuted = !player.isMuted
    }
    
    @IBAction func volumeSliderAction(_ sender: Any?) {
        player.volume = Float(volumeSlider.doubleValue)
    }
    
    @IBAction func showSubtitlesMenu(_ sender: PUIButton) {
        // TODO: show subtitles menu
    }
    
    @IBAction public func togglePlaying(_ sender: Any?) {
        if isPlaying {
            player.rate = 0
        } else {
            player.rate = playbackSpeed.rawValue
        }
    }
    
    @IBAction public func previousAnnotation(_ sender: Any?) {
        guard let annotation = firstAnnotationBeforeCurrentTime else { return }
        
        seek(to: annotation)
    }
    
    @IBAction public func nextAnnotation(_ sender: Any?) {
        guard let annotation = firstAnnotationAfterCurrentTime else { return }
        
        seek(to: annotation)
    }
    
    @IBAction public func goBackInTime(_ sender: Any?) {
        modifyCurrentTime(with: 30, using: CMTimeSubtract)
    }
    
    @IBAction public func goForwardInTime(_ sender: Any?) {
        modifyCurrentTime(with: 30, using: CMTimeAdd)
    }
    
    @IBAction public func toggleSpeed(_ sender: Any?) {
        playbackSpeed = playbackSpeed.next
    }
    
    @IBAction public func addAnnotation(_ sender: NSView?) {
        // TODO: handle add annotation (probably with delegate method)
    }
    
    @IBAction public func togglePip(_ sender: NSView?) {
        // TODO: handle PiP (probably with delegate method - PiP is implemented in the app, not the framework)
    }
    
    private func modifyCurrentTime(with seconds: Double, using function: (CMTime, CMTime) -> CMTime) {
        guard let durationTime = player.currentItem?.duration else { return }
        
        let modifier = CMTimeMakeWithSeconds(seconds, durationTime.timescale)
        let targetTime = function(player.currentTime(), modifier)
        
        guard targetTime.isValid && targetTime.isNumeric else { return }
        
        player.seek(to: targetTime)
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
            self.controlsVisualEffectView.animator().alphaValue = opacity
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
            if togglesPlaybackOnSingleClick {
                if isPlaying {
                    player.pause()
                } else {
                    player.play()
                }
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
