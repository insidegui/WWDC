//
//  PUIPlayerView.swift
//  PlayerProto
//
//  Created by Guilherme Rambo on 29/04/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
import AVFoundation
import os.log

public final class PUIPlayerView: NSView {

    private let log = OSLog(subsystem: "PlayerUI", category: "PUIPlayerView")

    // MARK: - Public API

    public weak var delegate: PUIPlayerViewDelegate?

    public internal(set) var isInPictureInPictureMode: Bool = false {
        didSet {
            guard isInPictureInPictureMode != oldValue else { return }

            pipButton.state = isInPictureInPictureMode ? .on : .off

            if isInPictureInPictureMode {
                externalStatusController.providerIcon = .PUIPictureInPictureLarge
                externalStatusController.providerName = "Picture in Picture"
                externalStatusController.providerDescription = "Playing in Picture in Picture"
                externalStatusController.view.isHidden = false
            } else {
                externalStatusController.view.isHidden = true
            }

            invalidateTouchBar()
        }
    }

    public weak var appearanceDelegate: PUIPlayerViewAppearanceDelegate? {
        didSet {
            invalidateAppearance()
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

    public var annotations: [PUITimelineAnnotation] {
        get {
            return sortedAnnotations
        }
        set {
            sortedAnnotations = newValue.filter({ $0.isValid }).sorted(by: { $0.timestamp < $1.timestamp })

            timelineView.annotations = sortedAnnotations
        }
    }

    public weak var player: AVPlayer? {
        didSet {
            guard oldValue != player else { return }

            if let oldPlayer = oldValue {
                teardown(player: oldPlayer)
            }

            guard player != nil else { return }

            setupPlayer()
        }
    }

    public var isInFullScreenPlayerWindow: Bool {
        return window is PUIPlayerWindow
    }

    public var remoteMediaUrl: URL?
    public var mediaPosterUrl: URL?
    public var mediaTitle: String?
    public var mediaIsLiveStream: Bool = false

    var pictureContainer: PUIPictureContainerViewController!

    public init(player: AVPlayer) {
        self.player = player

        super.init(frame: .zero)

        wantsLayer = true
        layer = PUIBoringLayer()
        layer?.backgroundColor = NSColor.black.cgColor

        setupPlayer()
        setupControls()
    }

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public var nowPlayingInfo: PUINowPlayingInfo? {
        didSet {
            nowPlayingCoordinator?.basicNowPlayingInfo = nowPlayingInfo
        }
    }

    public var isPlaying: Bool {
        if let externalProvider = currentExternalPlaybackProvider {
            return !externalProvider.status.rate.isZero
        } else {
            return isInternalPlayerPlaying
        }
    }

    public var isInternalPlayerPlaying: Bool {
        guard let player = player else { return false }

        return !player.rate.isZero
    }

    public var currentTimestamp: Double {
        guard let player = player else { return 0 }

        if let externalProvider = currentExternalPlaybackProvider {
            return Double(externalProvider.status.currentTime)
        } else {
            return Double(CMTimeGetSeconds(player.currentTime()))
        }
    }

    public var firstAnnotationBeforeCurrentTime: PUITimelineAnnotation? {
        return annotations.reversed().first { $0.isValid && $0.timestamp + 1 < currentTimestamp }
    }

    public var firstAnnotationAfterCurrentTime: PUITimelineAnnotation? {
        return annotations.first { $0.isValid && $0.timestamp > currentTimestamp + 1 }
    }

    public func seek(to annotation: PUITimelineAnnotation) {
        seek(to: annotation.timestamp)
    }

    public var playbackSpeed: PUIPlaybackSpeed = .normal {
        didSet {
            guard let player = player else { return }

            if isPlaying && !isPlayingExternally {
                player.rate = playbackSpeed.rawValue
                player.seek(to: player.currentTime()) // Helps the AV sync when speeds change with the TimeDomain algorithm enabled
            }

            updatePlaybackSpeedState()
            updateSelectedMenuItem(forPlaybackSpeed: playbackSpeed)

            invalidateTouchBar()
        }
    }

    public var isPlayingExternally: Bool {
        return currentExternalPlaybackProvider != nil
    }

    public var hideAllControls: Bool = false {
        didSet {
            controlsContainerView.isHidden = hideAllControls
            extrasMenuContainerView.isHidden = hideAllControls
        }
    }

    // MARK: External playback

    fileprivate(set) var externalPlaybackProviders: [PUIExternalPlaybackProviderRegistration] = [] {
        didSet {
            updateExternalPlaybackMenus()
        }
    }

    public func registerExternalPlaybackProvider(_ provider: PUIExternalPlaybackProvider.Type) {
        // prevent registering the same provider multiple times
        guard !externalPlaybackProviders.contains(where: { type(of: $0.provider).name == provider.name }) else {
            os_log("Tried to register provider %{public}@ which was already registered", log: log, type: .error, provider.name)
            return
        }

        let instance = provider.init(consumer: self)
        let button = self.button(for: instance)
        let registration = PUIExternalPlaybackProviderRegistration(provider: instance, button: button, menu: NSMenu())

        externalPlaybackProviders.append(registration)
    }

    public func invalidateAppearance() {
        configureWithAppearanceFromDelegate()
    }

    // MARK: - Private API

    fileprivate weak var lastKnownWindow: NSWindow?

    private var sortedAnnotations: [PUITimelineAnnotation] = [] {
        didSet {
            updateAnnotationsState()
        }
    }

    private var playerTimeObserver: Any?

    fileprivate var asset: AVAsset? {
        return player?.currentItem?.asset
    }

    private var playerLayer = PUIBoringPlayerLayer()

    private func setupPlayer() {
        elapsedTimeLabel.stringValue = elapsedTimeInitialValue
        remainingTimeLabel.stringValue = remainingTimeInitialValue
        timelineView.resetUI()

        guard let player = player else { return }

        playerLayer.player = player
        playerLayer.videoGravity = .resizeAspect

        if pictureContainer == nil {
            pictureContainer = PUIPictureContainerViewController(playerLayer: playerLayer)
            pictureContainer.delegate = self
            pictureContainer.view.frame = bounds
            pictureContainer.view.autoresizingMask = [.width, .height]

            addSubview(pictureContainer.view)
        }

        player.addObserver(self, forKeyPath: #keyPath(AVPlayer.status), options: [.initial, .new], context: nil)
        player.addObserver(self, forKeyPath: #keyPath(AVPlayer.volume), options: [.initial, .new], context: nil)
        player.addObserver(self, forKeyPath: #keyPath(AVPlayer.rate), options: [.initial, .new], context: nil)
        player.addObserver(self, forKeyPath: #keyPath(AVPlayer.currentItem), options: [.initial, .new], context: nil)
        player.addObserver(self, forKeyPath: #keyPath(AVPlayer.currentItem.loadedTimeRanges), options: [.initial, .new], context: nil)

        asset?.loadValuesAsynchronously(forKeys: ["duration"], completionHandler: durationBecameAvailable)

        asset?.loadValuesAsynchronously(forKeys: ["availableMediaCharacteristicsWithMediaSelectionOptions"], completionHandler: { [weak self] in

            if self?.asset?.statusOfValue(forKey: "availableMediaCharacteristicsWithMediaSelectionOptions", error: nil) == .loaded {
                DispatchQueue.main.async { self?.updateSubtitleSelectionMenu() }
            }
        })

        playerTimeObserver = player.addPeriodicTimeObserver(forInterval: CMTimeMakeWithSeconds(0.5, preferredTimescale: 9000), queue: .main) { [weak self] currentTime in
            self?.playerTimeDidChange(time: currentTime)
        }

        setupNowPlayingCoordinatorIfSupported()
        setupRemoteCommandCoordinator()
    }

    private func teardown(player oldValue: AVPlayer) {
        oldValue.pause()
        oldValue.cancelPendingPrerolls()

        if let observer = playerTimeObserver {
            oldValue.removeTimeObserver(observer)
            playerTimeObserver = nil
        }

        oldValue.removeObserver(self, forKeyPath: #keyPath(AVPlayer.status))
        oldValue.removeObserver(self, forKeyPath: #keyPath(AVPlayer.rate))
        oldValue.removeObserver(self, forKeyPath: #keyPath(AVPlayer.volume))
        oldValue.removeObserver(self, forKeyPath: #keyPath(AVPlayer.currentItem.loadedTimeRanges))
        oldValue.removeObserver(self, forKeyPath: #keyPath(AVPlayer.currentItem))
    }

    public override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        DispatchQueue.main.async {
            guard let keyPath = keyPath else { return }

            switch keyPath {
            case #keyPath(AVPlayer.status):
                self.playerStatusChanged()
            case #keyPath(AVPlayer.currentItem.loadedTimeRanges):
                self.updateBufferedSegments()
            case #keyPath(AVPlayer.volume):
                self.playerVolumeChanged()
            case #keyPath(AVPlayer.rate):
                self.updatePlayingState()
                self.updatePowerAssertion()
            case #keyPath(AVPlayer.currentItem):
                if let playerItem = self.player?.currentItem {
                    playerItem.audioTimePitchAlgorithm = .timeDomain
                }
            default:
                super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
            }
        }
    }

    private func playerVolumeChanged() {
        guard let player = player else { return }

        if player.volume.isZero {
            volumeButton.image = .PUIVolumeMuted
            volumeSlider.doubleValue = 0
        } else {
            volumeButton.image = .PUIVolume
            volumeSlider.doubleValue = Double(player.volume)
        }
    }

    private func updateBufferedSegments() {
        guard let player = player else { return }

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

    fileprivate func updatePlayingState() {
        pipController?.setPlaying(isPlaying)

        if isPlaying {
            playButton.image = .PUIPause
        } else {
            playButton.image = .PUIPlay
        }
    }

    fileprivate var activity: NSObjectProtocol?

    fileprivate func updatePowerAssertion() {
        if player?.rate == 0 {
            if let activity = activity {
                ProcessInfo.processInfo.endActivity(activity)
                self.activity = nil
            }
        } else {
            if activity == nil {
                activity = ProcessInfo.processInfo.beginActivity(options: [.idleDisplaySleepDisabled, .userInitiated], reason: "Playing WWDC session video")
            }
        }
    }

    fileprivate func updatePlaybackSpeedState() {
        speedButton.image = playbackSpeed.icon
    }

    fileprivate var currentPresentationSize: NSSize? {
        guard let size = player?.currentItem?.presentationSize, size != NSSize.zero else { return nil }

        return size
    }

    private func playerStatusChanged() {
        guard let player = player else { return }

        switch player.status {
        case .readyToPlay:
            updateTimeLabels()
        default: break
        }
    }

    private func durationBecameAvailable() {
        guard let duration = asset?.duration else { return }

        DispatchQueue.main.async {
            self.timelineView.mediaDuration = Double(CMTimeGetSeconds(duration))
        }
    }

    fileprivate func playerTimeDidChange(time: CMTime) {
        guard let player = player else { return }
        guard player.hasValidMediaDuration else { return }
        guard let duration = asset?.durationIfLoaded else { return }

        DispatchQueue.main.async {
            let progress = Double(CMTimeGetSeconds(time) / CMTimeGetSeconds(duration))
            self.timelineView.playbackProgress = progress

            self.updateAnnotationsState()
            self.updateTimeLabels()
        }
    }

    private func updateTimeLabels() {
        guard let player = player else { return }

        guard player.hasValidMediaDuration else { return }
        guard let duration = asset?.durationIfLoaded else { return }

        let time = player.currentTime()

        elapsedTimeLabel.stringValue = String(time: time) ?? ""

        let remainingTime = CMTimeSubtract(duration, time)
        remainingTimeLabel.stringValue = String(time: remainingTime) ?? ""
    }

    deinit {
        if let player = player {
            teardown(player: player)
        }
    }

    // MARK: - Now Playing Coordination

    private var nowPlayingCoordinator: PUINowPlayingInfoCoordinator?

    private func setupNowPlayingCoordinatorIfSupported() {
        guard let player = player else { return }

        nowPlayingCoordinator = PUINowPlayingInfoCoordinator(player: player)
        nowPlayingCoordinator?.basicNowPlayingInfo = nowPlayingInfo
    }

    // MARK: - Remote command support (AirPlay 2)

    private var remoteCommandCoordinator: PUIRemoteCommandCoordinator?

    private func setupRemoteCommandCoordinator() {
        remoteCommandCoordinator = PUIRemoteCommandCoordinator()

        remoteCommandCoordinator?.pauseHandler = { [weak self] in
            self?.pause(nil)
        }
        remoteCommandCoordinator?.playHandler = { [weak self] in
            self?.play(nil)
        }
        remoteCommandCoordinator?.stopHandler = { [weak self] in
            self?.pause(nil)
        }
        remoteCommandCoordinator?.togglePlayingHandler = { [weak self] in
            self?.togglePlaying(nil)
        }
        remoteCommandCoordinator?.nextTrackHandler = { [weak self] in
            self?.goForwardInTime(nil)
        }
        remoteCommandCoordinator?.previousTrackHandler = { [weak self] in
            self?.goBackInTime(nil)
        }
        remoteCommandCoordinator?.likeHandler = { [weak self] in
            guard let self = self else { return }

            self.delegate?.playerViewDidSelectLike(self)
        }
        remoteCommandCoordinator?.changePlaybackPositionHandler = { [weak self] time in
            self?.seek(to: time)
        }
        remoteCommandCoordinator?.changePlaybackRateHandler = { [weak self] speed in
            self?.playbackSpeed = speed
        }
    }

    // MARK: Controls

    fileprivate var wasPlayingBeforeStartingInteractiveSeek = false

    private var extrasMenuContainerView: NSStackView!
    fileprivate var scrimContainerView: PUIScrimView!
    private var controlsContainerView: NSStackView!
    private var volumeControlsContainerView: NSStackView!
    private var centerButtonsContainerView: NSStackView!

    fileprivate lazy var timelineView: PUITimelineView = {
        let v = PUITimelineView(frame: .zero)

        v.viewDelegate = self

        return v
    }()

    private var elapsedTimeInitialValue = "00:00:00"
    private lazy var elapsedTimeLabel: NSTextField = {
        let l = NSTextField(labelWithString: elapsedTimeInitialValue)

        l.alignment = .left
        l.font = .monospacedDigitSystemFont(ofSize: 14, weight: .medium)
        l.textColor = .timeLabel

        return l
    }()

    private var remainingTimeInitialValue = "-00:00:00"
    private lazy var remainingTimeLabel: NSTextField = {
        let l = NSTextField(labelWithString: remainingTimeInitialValue)

        l.alignment = .right
        l.font = .monospacedDigitSystemFont(ofSize: 14, weight: .medium)
        l.textColor = .timeLabel

        return l
    }()

    private lazy var fullScreenButton: PUIVibrantButton = {
        let b = PUIVibrantButton(frame: .zero)

        b.button.image = .PUIFullScreen
        b.button.target = self
        b.button.action = #selector(toggleFullscreen)
        b.button.toolTip = "Toggle full screen"

        return b
    }()

    private lazy var volumeButton: PUIButton = {
        let b = PUIButton(frame: .zero)

        b.image = .PUIVolume
        b.target = self
        b.action = #selector(toggleMute)
        b.widthAnchor.constraint(equalToConstant: 24).isActive = true
        b.toolTip = "Mute/unmute"

        return b
    }()

    fileprivate lazy var volumeSlider: PUISlider = {
        let s = PUISlider(frame: .zero)

        s.widthAnchor.constraint(equalToConstant: 88).isActive = true
        s.isContinuous = true
        s.target = self
        s.minValue = 0
        s.maxValue = 1
        s.action = #selector(volumeSliderAction)

        return s
    }()

    private lazy var subtitlesButton: PUIButton = {
        let b = PUIButton(frame: .zero)

        b.image = .PUISubtitles
        b.target = self
        b.action = #selector(showSubtitlesMenu)
        b.toolTip = "Subtitles"

        return b
    }()

    fileprivate lazy var playButton: PUIButton = {
        let b = PUIButton(frame: .zero)

        b.image = .PUIPlay
        b.target = self
        b.action = #selector(togglePlaying)
        b.toolTip = "Play/pause"

        return b
    }()

    private lazy var previousAnnotationButton: PUIButton = {
        let b = PUIButton(frame: .zero)

        b.image = .PUIPreviousAnnotation
        b.target = self
        b.action = #selector(previousAnnotation)
        b.toolTip = "Go to previous bookmark"

        return b
    }()

    private lazy var nextAnnotationButton: PUIButton = {
        let b = PUIButton(frame: .zero)

        b.image = .PUINextAnnotation
        b.target = self
        b.action = #selector(nextAnnotation)
        b.toolTip = "Go to next bookmark"

        return b
    }()

    private lazy var backButton: PUIButton = {
        let b = PUIButton(frame: .zero)

        b.image = .PUIBack15s
        b.target = self
        b.action = #selector(goBackInTime15)
        b.toolTip = "Go back 15s"

        return b
    }()

    private lazy var forwardButton: PUIButton = {
        let b = PUIButton(frame: .zero)

        b.image = .PUIForward15s
        b.target = self
        b.action = #selector(goForwardInTime15)
        b.toolTip = "Go forward 15s"

        return b
    }()

    fileprivate lazy var speedButton: PUIButton = {
        let b = PUIButton(frame: .zero)

        b.image = .PUISpeedOne
        b.target = self
        b.action = #selector(toggleSpeed)
        b.toolTip = "Change playback speed"
        b.menu = self.speedsMenu
        b.showsMenuOnRightClick = true

        return b
    }()

    private lazy var addAnnotationButton: PUIButton = {
        let b = PUIButton(frame: .zero)

        b.image = .PUIAnnotation
        b.target = self
        b.action = #selector(addAnnotation)
        b.toolTip = "Add bookmark"

        return b
    }()

    private lazy var pipButton: PUIButton = {
        let b = PUIButton(frame: .zero)

        b.isToggle = true
        b.image = .PUIPictureInPicture
        b.target = self
        b.action = #selector(togglePip)
        b.toolTip = "Toggle picture in picture"

        return b
    }()

    private var extrasMenuTopConstraint: NSLayoutConstraint!

    private lazy var externalStatusController = PUIExternalPlaybackStatusViewController()

    private func setupControls() {
        externalStatusController.view.isHidden = true
        externalStatusController.view.translatesAutoresizingMaskIntoConstraints = false
        addSubview(externalStatusController.view)
        externalStatusController.view.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
        externalStatusController.view.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true
        externalStatusController.view.topAnchor.constraint(equalTo: topAnchor).isActive = true
        externalStatusController.view.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true

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
        centerButtonsContainerView.setVisibilityPriority(.detachOnlyIfNecessary, for: volumeButton)
        centerButtonsContainerView.setVisibilityPriority(.detachOnlyIfNecessary, for: volumeSlider)
        centerButtonsContainerView.setVisibilityPriority(.detachOnlyIfNecessary, for: subtitlesButton)
        centerButtonsContainerView.setVisibilityPriority(.detachOnlyIfNecessary, for: backButton)
        centerButtonsContainerView.setVisibilityPriority(.detachOnlyIfNecessary, for: previousAnnotationButton)
        centerButtonsContainerView.setVisibilityPriority(.mustHold, for: playButton)
        centerButtonsContainerView.setVisibilityPriority(.detachOnlyIfNecessary, for: forwardButton)
        centerButtonsContainerView.setVisibilityPriority(.detachOnlyIfNecessary, for: nextAnnotationButton)
        centerButtonsContainerView.setVisibilityPriority(.detachOnlyIfNecessary, for: speedButton)
        centerButtonsContainerView.setVisibilityPriority(.detachOnlyIfNecessary, for: addAnnotationButton)
        centerButtonsContainerView.setVisibilityPriority(.detachOnlyIfNecessary, for: pipButton)
        centerButtonsContainerView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let timelineContainerView = NSStackView(views: [
            elapsedTimeLabel,
            timelineView,
            remainingTimeLabel
        ])
        timelineContainerView.distribution = .equalSpacing
        timelineContainerView.orientation = .horizontal
        timelineContainerView.alignment = .lastBaseline

        // Main stack view and background scrim
        controlsContainerView = NSStackView(views: [
            timelineContainerView,
            centerButtonsContainerView
            ])

        controlsContainerView.orientation = .vertical
        controlsContainerView.spacing = 12
        controlsContainerView.distribution = .fill
        controlsContainerView.translatesAutoresizingMaskIntoConstraints = false
        controlsContainerView.wantsLayer = true
        controlsContainerView.layer?.masksToBounds = false
        controlsContainerView.layer?.zPosition = 10

        scrimContainerView = PUIScrimView(frame: controlsContainerView.bounds)

        addSubview(scrimContainerView)
        addSubview(controlsContainerView)

        scrimContainerView.translatesAutoresizingMaskIntoConstraints = false
        scrimContainerView.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
        scrimContainerView.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true
        scrimContainerView.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true
        scrimContainerView.heightAnchor.constraint(equalTo: controlsContainerView.heightAnchor, multiplier: 1.4, constant: 0).isActive = true

        controlsContainerView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12).isActive = true
        controlsContainerView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12).isActive = true
        controlsContainerView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12).isActive = true

        centerButtonsContainerView.leadingAnchor.constraint(equalTo: controlsContainerView.leadingAnchor).isActive = true
        centerButtonsContainerView.trailingAnchor.constraint(equalTo: controlsContainerView.trailingAnchor).isActive = true

        // Extras menu (external playback, fullscreen button)
        extrasMenuContainerView = NSStackView(views: [fullScreenButton])
        extrasMenuContainerView.orientation = .horizontal
        extrasMenuContainerView.alignment = .centerY
        extrasMenuContainerView.distribution = .equalSpacing
        extrasMenuContainerView.spacing = 30

        addSubview(extrasMenuContainerView)

        extrasMenuContainerView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12).isActive = true
        updateExtrasMenuPosition()
    }

    var isConfiguredForBackAndForward30s = false {
        didSet {
            invalidateTouchBar()
        }
    }

    var goBackInTimeImage: NSImage {
        return isConfiguredForBackAndForward30s ? .PUIBack30s : .PUIBack15s
    }

    var goBackInTimeDescription: String {
        return isConfiguredForBackAndForward30s ? "Go back 30s" : "Go back 15s"
    }

    var goForwardInTimeImage: NSImage {
        return isConfiguredForBackAndForward30s ? .PUIForward30s : .PUIForward15s
    }

    var goForwardInTimeDescription: String {
        return isConfiguredForBackAndForward30s ? "Go forward 30s" : "Go forward 15s"
    }

    private func configureWithAppearanceFromDelegate() {
        guard let d = appearanceDelegate else { return }

        subtitlesButton.isHidden = !d.playerViewShouldShowSubtitlesControl(self)
        pipButton.isHidden = !d.playerViewShouldShowPictureInPictureControl(self)
        speedButton.isHidden = !d.playerViewShouldShowSpeedControl(self)

        let disableAnnotationControls = !d.playerViewShouldShowAnnotationControls(self)
        addAnnotationButton.isHidden = disableAnnotationControls
        previousAnnotationButton.isHidden = disableAnnotationControls
        nextAnnotationButton.isHidden = disableAnnotationControls

        let disableBackAndForward = !d.playerViewShouldShowBackAndForwardControls(self)
        backButton.isHidden = disableBackAndForward
        forwardButton.isHidden = disableBackAndForward

        isConfiguredForBackAndForward30s = d.playerViewShouldShowBackAndForward30SecondsButtons(self)
        backButton.image = goBackInTimeImage
        backButton.action = #selector(goBackInTime)
        backButton.toolTip = goBackInTimeDescription
        forwardButton.image = goForwardInTimeImage
        forwardButton.action = #selector(goForwardInTime)
        forwardButton.toolTip = goForwardInTimeDescription

        updateExternalPlaybackControlsAvailability()

        fullScreenButton.isHidden = !d.playerViewShouldShowFullScreenButton(self)
        timelineView.isHidden = !d.playerViewShouldShowTimelineView(self)
    }

    fileprivate func updateExternalPlaybackControlsAvailability() {
        guard let d = appearanceDelegate else { return }

        let disableExternalPlayback = !d.playerViewShouldShowExternalPlaybackControls(self)
        externalPlaybackProviders.forEach({ $0.button.isHidden = disableExternalPlayback })
    }

    private var isDominantViewInWindow: Bool {
        guard let contentView = window?.contentView else { return false }
        guard contentView != self else { return true }

        return bounds.height >= contentView.bounds.height
    }

    private func updateExtrasMenuPosition() {
        let topConstant: CGFloat = isDominantViewInWindow ? 34 : 12

        if extrasMenuTopConstraint == nil {
            extrasMenuTopConstraint = extrasMenuContainerView.topAnchor.constraint(equalTo: topAnchor, constant: topConstant)
            extrasMenuTopConstraint.isActive = true
        } else {
            extrasMenuTopConstraint.constant = topConstant
        }
    }

    fileprivate func updateExternalPlaybackMenus() {
        // clean menu
        extrasMenuContainerView.arrangedSubviews.enumerated().forEach { idx, view in
            guard idx < extrasMenuContainerView.arrangedSubviews.count - 1 else { return }

            extrasMenuContainerView.removeArrangedSubview(view)
        }

        // repopulate
        externalPlaybackProviders.filter({ $0.provider.isAvailable }).forEach { registration in
            registration.button.menu = registration.menu
            extrasMenuContainerView.insertArrangedSubview(registration.button, at: 0)
        }
    }

    private func button(for provider: PUIExternalPlaybackProvider) -> PUIButton {
        let b = PUIButton(frame: .zero)

        b.image = provider.icon
        b.toolTip = type(of: provider).name
        b.showsMenuOnLeftClick = true

        return b
    }

    // MARK: - Control actions

    private var playerVolumeBeforeMuting: Float = 1.0

    @IBAction public func toggleMute(_ sender: Any?) {
        guard let player = player else { return }

        if player.volume.isZero {
            player.volume = playerVolumeBeforeMuting
        } else {
            playerVolumeBeforeMuting = player.volume
            player.volume = 0
        }
    }

    @IBAction func volumeSliderAction(_ sender: Any?) {
        guard let player = player else { return }

        let v = Float(volumeSlider.doubleValue)

        if isPlayingExternally {
            currentExternalPlaybackProvider?.setVolume(v)
        } else {
            player.volume = v
        }
    }

    @IBAction public func togglePlaying(_ sender: Any?) {
        if isPlaying {
            pause(sender)
        } else {
            play(sender)
        }

        invalidateTouchBar()
    }

    @IBAction public func pause(_ sender: Any?) {
        if isPlayingExternally {
            currentExternalPlaybackProvider?.pause()
        } else {
            player?.rate = 0
        }
    }

    @IBAction public func play(_ sender: Any?) {
        guard isEnabled else { return }

        if player?.error != nil
            || player?.currentItem?.error != nil,
            let asset = player?.currentItem?.asset as? AVURLAsset {

            // reset the player on error
            player?.replaceCurrentItem(with: AVPlayerItem(asset: AVURLAsset(url: asset.url)))
        }

        if isPlayingExternally {
            currentExternalPlaybackProvider?.play()
        } else {
            guard let player = player else { return }
            if player.hasFinishedPlaying {
                seek(to: 0)
            }

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
        if isConfiguredForBackAndForward30s {
            goBackInTime30(sender)
        } else {
            goBackInTime15(sender)
        }
    }

    @IBAction public func goForwardInTime(_ sender: Any?) {
        if isConfiguredForBackAndForward30s {
            goForwardInTime30(sender)
        } else {
            goForwardInTime15(sender)
        }
    }

    @IBAction public func goBackInTime15(_ sender: Any?) {
        modifyCurrentTime(with: 15, using: CMTimeSubtract)
    }

    @IBAction public func goForwardInTime15(_ sender: Any?) {
        modifyCurrentTime(with: 15, using: CMTimeAdd)
    }

    @IBAction public func goBackInTime30(_ sender: Any?) {
        modifyCurrentTime(with: 30, using: CMTimeSubtract)
    }

    @IBAction public func goForwardInTime30(_ sender: Any?) {
        modifyCurrentTime(with: 30, using: CMTimeAdd)
    }

    @IBAction public func toggleSpeed(_ sender: Any?) {
        if NSEvent.modifierFlags.contains(.option) {
            playbackSpeed = playbackSpeed.previous
        } else {
            playbackSpeed = playbackSpeed.next
        }
    }
    
    public func reduceSpeed() {
        guard let speedIndex = PUIPlaybackSpeed.all.firstIndex(of: playbackSpeed) else { return }
        if speedIndex > 0 {
            playbackSpeed = PUIPlaybackSpeed.all[speedIndex - 1]
            showControls(animated: true)
            resetMouseIdleTimer()
        }
    }
    
    public func increaseSpeed() {
        guard let speedIndex = PUIPlaybackSpeed.all.firstIndex(of: playbackSpeed) else { return }
        if speedIndex < PUIPlaybackSpeed.all.count - 1 {
            playbackSpeed = PUIPlaybackSpeed.all[speedIndex + 1]
            showControls(animated: true)
            resetMouseIdleTimer()
        }
    }

    @IBAction public func addAnnotation(_ sender: NSView?) {
        guard let player = player else { return }

        let timestamp = Double(CMTimeGetSeconds(player.currentTime()))

        delegate?.playerViewDidSelectAddAnnotation(self, at: timestamp)
    }

    @IBAction public func togglePip(_ sender: NSView?) {
        if isInPictureInPictureMode {
            exitPictureInPictureMode()
        } else {
            enterPictureInPictureMode()
        }
    }

    @IBAction public func toggleFullscreen(_ sender: Any?) {
        delegate?.playerViewDidSelectToggleFullScreen(self)
    }

    private func modifyCurrentTime(with seconds: Double, using function: (CMTime, CMTime) -> CMTime) {
        guard let player = player else { return }

        guard let durationTime = player.currentItem?.duration else { return }

        let modifier = CMTimeMakeWithSeconds(seconds, preferredTimescale: durationTime.timescale)
        let targetTime = function(player.currentTime(), modifier)

        seek(to: targetTime)
    }

    private func seek(to timestamp: TimeInterval) {
        seek(to: CMTimeMakeWithSeconds(timestamp, preferredTimescale: 90000))
    }

    private func seek(to time: CMTime) {
        guard time.isValid && time.isNumeric else { return }

        if isPlayingExternally {
            currentExternalPlaybackProvider?.seek(to: CMTimeGetSeconds(time))
        } else {
            player?.seek(to: time)
        }
    }

    private func invalidateTouchBar(destructive: Bool = false) {
        touchBarController.invalidate(destructive)
    }

    // MARK: - Subtitles

    private var subtitlesMenu: NSMenu?
    private var subtitlesGroup: AVMediaSelectionGroup?

    private func updateSubtitleSelectionMenu() {
        guard let playerItem = player?.currentItem else { return }

        guard let subtitlesGroup = playerItem.asset.mediaSelectionGroup(forMediaCharacteristic: .legible) else {
            subtitlesButton.isHidden = true
            return
        }

        self.subtitlesGroup = subtitlesGroup

        subtitlesButton.isHidden = false

        let menu = NSMenu()

        subtitlesGroup.options.forEach { option in
            let item = NSMenuItem(title: option.displayName, action: #selector(didSelectSubtitleOption), keyEquivalent: "")
            item.representedObject = option
            item.target = self

            menu.addItem(item)
        }

        subtitlesMenu = menu
    }

    @objc fileprivate func didSelectSubtitleOption(_ sender: NSMenuItem) {
        guard let subtitlesGroup = subtitlesGroup else { return }
        guard let option = sender.representedObject as? AVMediaSelectionOption else { return }

        // reset all item's states
        sender.menu?.items.forEach({ $0.state = .on })

        if option.extendedLanguageTag == player?.currentItem?.currentMediaSelection.selectedMediaOption(in: subtitlesGroup)?.extendedLanguageTag {
            player?.currentItem?.select(nil, in: subtitlesGroup)
            sender.state = .off
            return
        }

        player?.currentItem?.select(option, in: subtitlesGroup)

        sender.state = .on
    }

    @IBAction func showSubtitlesMenu(_ sender: PUIButton) {
        subtitlesMenu?.popUp(positioning: nil, at: .zero, in: sender)
    }

    // MARK: - Playback speeds

    fileprivate lazy var speedsMenu: NSMenu = {
        let m = NSMenu()
        for speed in PUIPlaybackSpeed.all {
            let item = NSMenuItem(title: "\(String(format: "%g", speed.rawValue))x", action: #selector(didSelectSpeed), keyEquivalent: "")
            item.target = self
            item.representedObject = speed
            item.state = speed == self.playbackSpeed ? .on : .off
            m.addItem(item)
        }
        return m
    }()

    fileprivate func updateSelectedMenuItem(forPlaybackSpeed speed: PUIPlaybackSpeed) {
        for item in speedsMenu.items {
            item.state = (item.representedObject as? PUIPlaybackSpeed) == speed ? .on : .off
        }
    }

    @objc private func didSelectSpeed(_ sender: NSMenuItem) {
        guard let speed = sender.representedObject as? PUIPlaybackSpeed else {
            return
        }
        playbackSpeed = speed
    }

    // MARK: - Key commands

    private var keyDownEventMonitor: Any?

    private enum KeyCommands: UInt16 {
        case spaceBar = 49
        case leftArrow = 123
        case rightArrow = 124
        case minus = 27
        case plus = 24
        case j = 38
        case k = 40
        case l = 37
    }

    public var isEnabled = true {
        didSet {
            guard isEnabled != oldValue else { return }
            if !isEnabled { hideControls(animated: true) }
        }
    }

    private func startMonitoringKeyEvents() {
        if keyDownEventMonitor != nil {
            stopMonitoringKeyEvents()
        }

        keyDownEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [unowned self] event in
            guard self.isEnabled else { return event }

            guard let command = KeyCommands(rawValue: event.keyCode) else {
                return event
            }

            let allWindows = NSApp.windows
            let firstResponders = allWindows.compactMap { $0.firstResponder }
            let fieldEditors = firstResponders.filter { ($0 as? NSText)?.isEditable == true }
            guard fieldEditors.isEmpty else { return event }
            guard !self.timelineView.isEditingAnnotation else { return event }

            switch command {
            case .spaceBar, .k:
                self.togglePlaying(nil)
                return nil

            case .leftArrow, .j:
                self.goBackInTime(nil)
                return nil

            case .rightArrow, .l:
                self.goForwardInTime(nil)
                return nil
 
            case .minus:
                self.reduceSpeed()
                return nil
 
            case .plus:
                self.increaseSpeed()
                return nil
            }
        }
    }

    private func stopMonitoringKeyEvents() {
        if let keyDownEventMonitor = keyDownEventMonitor {
            NSEvent.removeMonitor(keyDownEventMonitor)
        }

        keyDownEventMonitor = nil
    }

    // MARK: - Touch Bar

    private lazy var touchBarController: PUITouchBarController = {
        return PUITouchBarController(playerView: self)
    }()

    public override func makeTouchBar() -> NSTouchBar? {
        return touchBarController.makeTouchBar()
    }

    // MARK: - PiP Support

    public func snapshotPlayer(completion: @escaping (CGImage?) -> Void) {
        guard let currentTime = player?.currentTime() else {
            completion(nil)
            return
        }
        guard let asset = player?.currentItem?.asset else {
            completion(nil)
            return
        }

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true

        let time = NSValue(time: currentTime)
        generator.generateCGImagesAsynchronously(forTimes: [time]) { _, rawImage, _, result, error in
            guard let rawImage = rawImage, error == nil else {
                DispatchQueue.main.async { completion(nil) }
                return
            }

            DispatchQueue.main.async { completion(rawImage) }
        }
    }

    fileprivate var pipController: PIPViewController?

    fileprivate func enterPictureInPictureMode() {
        delegate?.playerViewWillEnterPictureInPictureMode(self)

        snapshotPlayer { [weak self] image in
            self?.externalStatusController.snapshot = image
        }

        pipController = PIPViewController()
        pipController?.delegate = self
        pipController?.setPlaying(isPlaying)
        pipController?.aspectRatio = currentPresentationSize ?? NSSize(width: 640, height: 360)
        pipController?.view.layer?.backgroundColor = NSColor.black.cgColor

        pipController?.presentAsPicture(inPicture: pictureContainer)

        isInPictureInPictureMode = true
    }

    fileprivate func exitPictureInPictureMode() {
        if pictureContainer.presentingViewController == pipController {
            pipController?.dismiss(pictureContainer)
        }
    }

    // MARK: - Visibility management

    fileprivate var canHideControls: Bool {
        guard let player = player else { return false }

        guard isPlaying else { return false }
        guard player.status == .readyToPlay else { return false }
        guard let window = window else { return false }
        guard window.isOnActiveSpace && window.isVisible else { return false }

        guard !timelineView.isEditingAnnotation else { return false }

        let windowMouseRect = window.convertFromScreen(NSRect(origin: NSEvent.mouseLocation, size: CGSize(width: 1, height: 1)))
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
            mouseIdleTimer = Timer.scheduledTimer(timeInterval: 3.0, target: self, selector: #selector(mouseIdleTimerAction), userInfo: nil, repeats: false)
        }
    }

    @objc fileprivate func mouseIdleTimerAction(_ sender: Timer) {
        guard canHideControls else { return }

        if !isInPictureInPictureMode {
            NSCursor.hide()
        }

        hideControls(animated: true)
    }

    private func hideControls(animated: Bool) {
        guard canHideControls else { return }

        setControls(opacity: 0, animated: animated)
    }

    private func showControls(animated: Bool) {
        NSCursor.unhide()

        guard isEnabled else { return }

        setControls(opacity: 1, animated: animated)
    }

    private func setControls(opacity: CGFloat, animated: Bool) {
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = animated ? 0.4 : 0.0
            scrimContainerView.animator().alphaValue = opacity
            controlsContainerView.animator().alphaValue = opacity
            extrasMenuContainerView.animator().alphaValue = opacity
        }, completionHandler: nil)
    }

    public override func viewWillMove(toWindow newWindow: NSWindow?) {

        NotificationCenter.default.removeObserver(self, name: NSWindow.willEnterFullScreenNotification, object: window)
        NotificationCenter.default.removeObserver(self, name: NSWindow.willExitFullScreenNotification, object: window)
        NotificationCenter.default.removeObserver(self, name: NSWindow.didResignMainNotification, object: window)
        NotificationCenter.default.removeObserver(self, name: NSWindow.didBecomeMainNotification, object: window)

        NotificationCenter.default.addObserver(self, selector: #selector(windowWillEnterFullScreen), name: NSWindow.willEnterFullScreenNotification, object: newWindow)
        NotificationCenter.default.addObserver(self, selector: #selector(windowWillExitFullScreen), name: NSWindow.willExitFullScreenNotification, object: newWindow)
        NotificationCenter.default.addObserver(self, selector: #selector(windowDidResignMain), name: NSWindow.didResignMainNotification, object: newWindow)
        NotificationCenter.default.addObserver(self, selector: #selector(windowDidBecomeMain), name: NSWindow.didBecomeMainNotification, object: newWindow)
    }

    public override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()

        resetMouseIdleTimer()
        updateExtrasMenuPosition()

        if window != nil {
            lastKnownWindow = window
            startMonitoringKeyEvents()
            invalidateTouchBar(destructive: true)
        }
    }

    var windowIsInFullScreen: Bool {
        guard let window = window else { return false }

        return window.styleMask.contains(.fullScreen)
    }

    @objc private func windowWillEnterFullScreen() {
        fullScreenButton.isHidden = true
        updateExtrasMenuPosition()
    }

    @objc private func windowWillExitFullScreen() {
        if let d = appearanceDelegate {
            fullScreenButton.isHidden = !d.playerViewShouldShowFullScreenButton(self)
        }

        updateExtrasMenuPosition()
    }

    @objc private func windowDidBecomeMain() {

        // becoming main in full screen means we're entering the space
        if windowIsInFullScreen {
            resetMouseIdleTimer(start: true)
        }
    }

    @objc private func windowDidResignMain() {

        // resigning main in full screen means we're leaving the space
        if windowIsInFullScreen {
            resetMouseIdleTimer(start: false)
        }
    }

    // MARK: - Events

    private var mouseTrackingArea: NSTrackingArea!

    public override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if mouseTrackingArea != nil {
            removeTrackingArea(mouseTrackingArea)
        }

        let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .mouseMoved, .activeAlways, .inVisibleRect]
        mouseTrackingArea = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)

        addTrackingArea(mouseTrackingArea)
    }

    public override func mouseEntered(with event: NSEvent) {
        showControls(animated: true)
        resetMouseIdleTimer()

        super.mouseEntered(with: event)
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

    public override var acceptsFirstResponder: Bool {
        return true
    }

    public override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }

    public override func mouseDown(with event: NSEvent) {
        if event.type == .leftMouseDown && event.clickCount == 2 {
            toggleFullscreen(self)
        } else {
            super.mouseDown(with: event)
        }
    }

    // MARK: - External playback state management

    private func unhighlightExternalPlaybackButtons() {
        externalPlaybackProviders.forEach { registration in
            registration.button.tintColor = .buttonColor
        }
    }

    fileprivate var currentExternalPlaybackProvider: PUIExternalPlaybackProvider? {
        didSet {
            if currentExternalPlaybackProvider != nil {
                perform(#selector(transitionToExternalPlayback), with: nil, afterDelay: 0)
            } else {
                transitionToInternalPlayback()
            }
        }
    }

    @objc private func transitionToExternalPlayback() {
        guard let current = currentExternalPlaybackProvider else {
            transitionToInternalPlayback()
            return
        }

        let currentProviderName = type(of: current).name

        unhighlightExternalPlaybackButtons()

        guard let registration = externalPlaybackProviders.first(where: { type(of: $0.provider).name == currentProviderName }) else { return }

        registration.button.tintColor = .playerHighlight

        snapshotPlayer { [weak self] image in
            self?.externalStatusController.snapshot = image
        }

        externalStatusController.providerIcon = current.image
        externalStatusController.providerName = currentProviderName
        externalStatusController.providerDescription = "Playing in \(currentProviderName)" + "\n" + current.info
        externalStatusController.view.isHidden = false

        pipButton.isEnabled = false
        subtitlesButton.isEnabled = false
        speedButton.isEnabled = false
        forwardButton.isEnabled = false
        backButton.isEnabled = false

        controlsContainerView.alphaValue = 0.5
    }

    @objc private func transitionToInternalPlayback() {
        unhighlightExternalPlaybackButtons()

        pipButton.isEnabled = true
        subtitlesButton.isEnabled = true
        speedButton.isEnabled = true
        forwardButton.isEnabled = true
        backButton.isEnabled = true

        controlsContainerView.alphaValue = 1

        externalStatusController.view.isHidden = true
    }

}

// MARK: - PUITimelineViewDelegate

extension PUIPlayerView: PUITimelineViewDelegate {

    func timelineDidReceiveForceTouch(at timestamp: Double) {
        guard let player = player else { return }

        let timestamp = Double(CMTimeGetSeconds(player.currentTime()))

        delegate?.playerViewDidSelectAddAnnotation(self, at: timestamp)
    }

    func timelineViewWillBeginInteractiveSeek() {
        wasPlayingBeforeStartingInteractiveSeek = isPlaying

        pause(nil)
    }

    func timelineViewDidSeek(to progress: Double) {
        guard let duration = asset?.duration else { return }

        let targetTime = progress * Double(CMTimeGetSeconds(duration))
        let time = CMTimeMakeWithSeconds(targetTime, preferredTimescale: duration.timescale)

        if isPlayingExternally {
            currentExternalPlaybackProvider?.seek(to: targetTime)
        } else {
            player?.seek(to: time)
        }
    }

    func timelineViewDidFinishInteractiveSeek() {
        if wasPlayingBeforeStartingInteractiveSeek {
            play(nil)
        }
    }

}

// MARK: - External playback support

extension PUIPlayerView: PUIExternalPlaybackConsumer {

    private func isCurrentProvider(_ provider: PUIExternalPlaybackProvider) -> Bool {
        guard let currentProvider = currentExternalPlaybackProvider else { return false }

        return type(of: provider).name == type(of: currentProvider).name
    }

    public func externalPlaybackProviderDidChangeMediaStatus(_ provider: PUIExternalPlaybackProvider) {
        volumeSlider.doubleValue = Double(provider.status.volume)

        if let speed = PUIPlaybackSpeed(rawValue: provider.status.rate) {
            playbackSpeed = speed
        }

        let time = CMTimeMakeWithSeconds(Float64(provider.status.currentTime), preferredTimescale: 9000)
        playerTimeDidChange(time: time)

        updatePlayingState()
    }

    public func externalPlaybackProviderDidChangeAvailabilityStatus(_ provider: PUIExternalPlaybackProvider) {
        updateExternalPlaybackMenus()
        updateExternalPlaybackControlsAvailability()

        if !provider.isAvailable && isCurrentProvider(provider) {
            // current provider got invalidated, go back to internal playback
            currentExternalPlaybackProvider = nil
        }
    }

    public func externalPlaybackProviderDidInvalidatePlaybackSession(_ provider: PUIExternalPlaybackProvider) {
        if isCurrentProvider(provider) {
            let wasPlaying = !provider.status.rate.isZero

            // provider session invalidated, go back to internal playback
            currentExternalPlaybackProvider = nil

            if wasPlaying {
                player?.play()
                updatePlayingState()
            }
        }
    }

    public func externalPlaybackProvider(_ provider: PUIExternalPlaybackProvider, deviceSelectionMenuDidChangeWith menu: NSMenu) {
        guard let registrationIndex = externalPlaybackProviders.firstIndex(where: { type(of: $0.provider).name == type(of: provider).name }) else { return }

        externalPlaybackProviders[registrationIndex].menu = menu
    }

    public func externalPlaybackProviderDidBecomeCurrent(_ provider: PUIExternalPlaybackProvider) {
        if isInternalPlayerPlaying {
            player?.rate = 0
        }

        currentExternalPlaybackProvider = provider
    }

}

// MARK: - PiP delegate

extension PUIPlayerView: PIPViewControllerDelegate, PUIPictureContainerViewControllerDelegate {

    public func pipActionStop(_ pip: PIPViewController) {
        pause(pip)
        delegate?.playerViewWillExitPictureInPictureMode(self, reason: .exitButton)
    }

    public func pipActionReturn(_ pip: PIPViewController) {
        delegate?.playerViewWillExitPictureInPictureMode(self, reason: .returnButton)

        if !NSApp.isActive {
            NSApp.activate(ignoringOtherApps: true)
        }

        if let window = lastKnownWindow {
            window.makeKeyAndOrderFront(pip)

            if window.isMiniaturized {
                window.deminiaturize(nil)
            }
        }
    }

    public func pipActionPause(_ pip: PIPViewController) {
        pause(pip)
    }

    public func pipActionPlay(_ pip: PIPViewController) {
        play(pip)
    }

    public func pipDidClose(_ pip: PIPViewController) {
        pictureContainer.view.frame = bounds

        addSubview(pictureContainer.view, positioned: .below, relativeTo: scrimContainerView)

        isInPictureInPictureMode = false
        pipController = nil
    }

    public func pipWillClose(_ pip: PIPViewController) {
        pip.replacementRect = frame
        pip.replacementView = self
        pip.replacementWindow = lastKnownWindow
    }

    func pictureContainerViewSuperviewDidChange(to superview: NSView?) {
        guard let superview = superview else { return }

        pictureContainer.view.frame = superview.bounds

        if superview == self, pipController != nil {
            if pictureContainer.presentingViewController == pipController {
                pipController?.dismiss(pictureContainer)
            }

            pipController = nil
        }
    }

}
