//
//  PUIPlayerView.swift
//  PlayerProto
//
//  Created by Guilherme Rambo on 29/04/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
import AVFoundation
import OSLog
import AVKit
import Combine
import SwiftUI
import ConfUIFoundation

public final class PUIPlayerView: NSView {

    private let settings = PUISettings()

    private let log = Logger(subsystem: "PlayerUI", category: "PUIPlayerView")
    private var cancellables: Set<AnyCancellable> = []
    /// Bindings that only need to be established once and are not dependent on the player (model).
    /// The nature of Combine forces us to store them somewhere, though. And as long as they only capture `self`
    /// weakly, the ui bindings don't need to be reset when the player changes.
    private var uiBindings: Set<AnyCancellable> = []

    // MARK: - Public API

    public weak var delegate: PUIPlayerViewDelegate?

    public var isInPictureInPictureMode: Bool { pipController?.isPictureInPictureActive == true }

    public weak var appearanceDelegate: PUIPlayerViewAppearanceDelegate? {
        didSet {
            invalidateAppearance()
        }
    }

    var shouldAdoptLiquidGlass = false

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

            validateAnnotationButton()
        }
    }

    public weak var player: AVPlayer? {
        didSet {
            guard oldValue != player else { return }

            if let oldPlayer = oldValue {
                teardown(player: oldPlayer)
            }

            guard let player else { return }

            setupPlayer(player)
        }
    }

    public var isInFullScreenPlayerWindow: Bool {
        return window is PUIPlayerWindow
    }

    public var remoteMediaUrl: URL?
    public var mediaPosterUrl: URL?
    public var mediaTitle: String?
    public var mediaIsLiveStream: Bool = false

    private var backgroundColor: NSColor? {
        get { layer?.backgroundColor.flatMap { NSColor(cgColor: $0) } }
        set { layer?.backgroundColor = newValue?.cgColor }
    }

    public init(player: AVPlayer, shouldAdoptLiquidGlass: Bool = false) {
        self.player = player
        if AVPictureInPictureController.isPictureInPictureSupported() {
            self.pipController = AVPictureInPictureController(contentSource: .init(playerLayer: playerLayer))
        } else {
            self.pipController = nil
        }
        self.shouldAdoptLiquidGlass = shouldAdoptLiquidGlass

        super.init(frame: .zero)

        wantsLayer = true
        layer = PUIBoringLayer()
        backgroundColor = .black

        setupPlayer(player)
        if #available(macOS 26.0, *), shouldAdoptLiquidGlass {
            setupTahoeControls()
        } else {
            setupControls()
        }
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
        guard let player = player else { return false }

        return !player.rate.isZero
    }

    public var currentTimestamp: Double {
        guard let player = player else { return 0 }

        return Double(CMTimeGetSeconds(player.currentTime()))
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

            if playbackSpeed != oldValue, isPlaying {
                player.rate = playbackSpeed.rawValue
                player.seek(to: player.currentTime()) // Helps the AV sync when speeds change with the TimeDomain algorithm enabled
            }

            settings.playbackRate = Double(playbackSpeed.rawValue)

            updatePlaybackSpeedState()

            invalidateTouchBar()
        }
    }

    public var hideAllControls: Bool = false {
        didSet {
            controlsContainerView.isHidden = hideAllControls
            topTrailingMenuContainerView.isHidden = hideAllControls
        }
    }

    public func invalidateAppearance() {
        configureWithAppearanceFromDelegate()
    }

    // MARK: - Private API

    fileprivate weak var lastKnownWindow: NSWindow?

    private var sortedAnnotations: [PUITimelineAnnotation] = []

    private var playerTimeObserver: Any?
    private var annotationTimeDistanceObserver: Any?

    fileprivate var asset: AVAsset? {
        return player?.currentItem?.asset
    }

    private let playerLayer = PUIBoringPlayerLayer()
    private var dimmingView: NSView?

    private func setupPlayer(_ player: AVPlayer) {
        /// User settings are applied before setting up player observations, avoiding accidental overrides when initial values come in.
        applyUserSettings(to: player)

        if let pipController {
            pipPossibleObservation = pipController.observe(
                \AVPictureInPictureController.isPictureInPicturePossible, options: [.initial, .new]
            ) { [weak self] _, change in
                self?.pipButton.isEnabled = change.newValue ?? false
            }
            pipController.delegate = self
        } else {
            pipButton.isEnabled = false
        }

        leadingTimeButton.title = elapsedTimePlaceholder
        trailingTimeButton.title = timeRemainingPlaceholder
        timelineView.resetUI()

        playerLayer.player = player
        playerLayer.videoGravity = .resizeAspect

        let options: NSKeyValueObservingOptions = [.initial, .new]
        player.publisher(for: \.status, options: options).sink { [weak self] change in
            self?.playerStatusChanged()
        }.store(in: &cancellables)
        player.publisher(for: \.volume, options: options).sink { [weak self] change in
            self?.playerVolumeChanged()
        }.store(in: &cancellables)
        player.publisher(for: \.rate, options: options).sink { [weak self] change in
            self?.updatePlayingState()
            self?.updatePowerAssertion()
        }.store(in: &cancellables)
        player.publisher(for: \.currentItem, options: options).sink { [weak self] change in
            if let playerItem = self?.player?.currentItem {
                playerItem.audioTimePitchAlgorithm = .timeDomain
            }
        }.store(in: &cancellables)
        player.publisher(for: \.currentItem?.loadedTimeRanges, options: [.initial, .new]).sink { [weak self] change in
            self?.updateBufferedSegments()
        }.store(in: &cancellables)

        player.publisher(for: \.currentItem?.tracks, options: [.initial, .new]).sink { [weak self] _ in
            self?.needsLayout = true
        }.store(in: &cancellables)

        Task { [weak self] in
            guard let asset = self?.asset else { return }
            async let duration = asset.load(.duration)
            async let legible = asset.loadMediaSelectionGroup(for: .legible)
            self?.timelineView.mediaDuration = Double(CMTimeGetSeconds(try await duration))
            self?.updateSubtitleSelectionMenu(subtitlesGroup: try await legible)
        }

        playerTimeObserver = player.addPeriodicTimeObserver(forInterval: CMTimeMakeWithSeconds(0.5, preferredTimescale: 9000), queue: .main) { [weak self] currentTime in
            self?.playerTimeDidChange(time: currentTime)
        }

        annotationTimeDistanceObserver = player.addPeriodicTimeObserver(forInterval: CMTimeMakeWithSeconds(1, preferredTimescale: 9000), queue: .main) { [weak self] _ in
            self?.validateAnnotationButton()
        }

        player.allowsExternalPlayback = true
        (routeButton as? PUIButton)?.player = player
        (routeButton as? PUIAVRoutPickerView)?.player = player

        setupNowPlayingCoordinatorIfSupported()
        setupRemoteCommandCoordinator()
    }

    private func teardown(player oldValue: AVPlayer) {
        oldValue.pause()
        oldValue.cancelPendingPrerolls()

        cancellables.removeAll()
        if let observer = playerTimeObserver {
            oldValue.removeTimeObserver(observer)
            playerTimeObserver = nil
        }
        if let observer = annotationTimeDistanceObserver {
            oldValue.removeTimeObserver(observer)
            annotationTimeDistanceObserver = nil
        }
    }

    private func applyUserSettings(to player: AVPlayer) {
        trailingLabelDisplaysDuration = settings.trailingLabelDisplaysDuration

        player.volume = Float(settings.playerVolume)

        let speed = Float(settings.playbackRate)
        if PUIPlaybackSpeed.validateCustomSpeed(speed) {
            playbackSpeed = PUIPlaybackSpeed(rawValue: speed) ?? .normal
        } else {
            log.error("Playback rate in user preference is invalid, using default (rate: \(speed, privacy: .public))")
        }
    }

    private func playerVolumeChanged() {
        guard let player = player else { return }

        settings.playerVolume = Double(player.volume)

        if player.volume.isZero {
            if shouldAdoptLiquidGlass {
                volumeButton.image = NSImage(systemSymbolName: "speaker.wave.3.fill", variableValue: 0, accessibilityDescription: "Volume")
            } else {
                volumeButton.image = .PUIVolumeMuted
            }
            volumeButton.toolTip = "Unmute"
            volumeSlider.doubleValue = 0
        } else {
            if shouldAdoptLiquidGlass {
                volumeButton.image = NSImage(systemSymbolName: "speaker.wave.3.fill", variableValue: Double(player.volume), accessibilityDescription: "Volume")
            } else {
                switch player.volume {
                case 0..<0.33:
                    volumeButton.image = .PUIVolume1
                case 0.33..<0.66:
                    volumeButton.image = .PUIVolume2
                default:
                    volumeButton.image = .PUIVolume3
                }
            }

            volumeButton.toolTip = "Mute"
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

    fileprivate func updatePlayingState() {
        if isPlaying {
            playButton.state = .on
        } else {
            playButton.state = .off
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

    @MainActor
    fileprivate func updatePlaybackSpeedState() {
        guard playbackSpeed != speedButton.speed else { return }
        speedButton.speed = playbackSpeed
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

    fileprivate func playerTimeDidChange(time: CMTime) {
        guard let player = player else { return }
        guard player.hasValidMediaDuration else { return }
        guard let duration = asset?.durationIfLoaded else { return }

        DispatchQueue.main.async {
            let progress = Double(CMTimeGetSeconds(time) / CMTimeGetSeconds(duration))
            self.timelineView.playbackProgress = progress

            self.updateTimeLabels()
        }
    }

    private var trailingLabelDisplaysDuration = false {
        didSet {
            guard trailingLabelDisplaysDuration != oldValue else { return }

            settings.trailingLabelDisplaysDuration = trailingLabelDisplaysDuration
            updateTimeLabels()
        }
    }

    private func updateTimeLabels() {
        guard let player = player else { return }

        guard player.hasValidMediaDuration else { return }
        guard let duration = asset?.durationIfLoaded else { return }

        let time = player.currentTime()

        leadingTimeButton.title = String(time: time) ?? ""

        if trailingLabelDisplaysDuration {
            trailingTimeButton.title = String(time: duration) ?? durationPlaceholder
        } else {
            let remainingTime = CMTimeSubtract(duration, time)
            trailingTimeButton.title = "−" + (String(time: remainingTime) ?? timeRemainingPlaceholder)
        }
    }
    lazy var trackingArea = NSTrackingArea(rect: bounds, options: [.activeInKeyWindow, .mouseMoved, .mouseEnteredAndExited], owner: self, userInfo: nil)
    public override func layout() {
        updateVideoLayoutGuide()

        if shouldAdoptLiquidGlass {
            if !trackingAreas.contains(trackingArea) {
                addTrackingArea(trackingArea)
            }
        }
        super.layout()
    }

    private lazy var videoLayoutGuideConstraints = [NSLayoutConstraint]()

    private var currentBounds: CGRect?

    private func updateVideoLayoutGuide() {
        guard !shouldAdoptLiquidGlass else {
            return
        }
        guard let player else { return }

        guard bounds != currentBounds else { return }

        player.updateLayout(guide: videoLayoutGuide, container: self, constraints: &videoLayoutGuideConstraints)

        currentBounds = bounds
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

    private var topTrailingMenuContainerView: NSView!
    fileprivate var scrimContainerView: NSView!
    private var controlsContainerView: NSView!
    private var volumeControlsContainerView: NSView!
    private var centerButtonsContainerView: NSView!
    private var timelineContainerView: NSView!
    private var floatingTimestampView: NSView?
    private var floatingTimestampModel: PUITimelineFloatingModel?

    fileprivate lazy var timelineView: PUITimelineView = {
        let v = PUITimelineView(frame: .zero)

        v.viewDelegate = self

        return v
    }()

    private var elapsedTimePlaceholder = "00:00"
    private var timeRemainingPlaceholder = "−00:00"
    private var durationPlaceholder = "00:00"

    /// Displays the elapsed time.
    /// This is a button for consistency with `trailingTimeButton`, but it doesn't have an action.
    private lazy var leadingTimeButton: NSButton = {
        let b = PUIFirstMouseButton(title: elapsedTimePlaceholder, target: nil, action: nil)

        b.contentTintColor = .timeLabel
        b.isBordered = false
        b.alignment = .left
        b.font = .monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        b.isEnabled = false
        /// Prevents the disabled button from dimming its contents.
        (b.cell as? NSButtonCell)?.imageDimsWhenDisabled = false

        return b
    }()

    /// Displays either elapsed time or duration according to user preference (toggle by clicking).
    private lazy var trailingTimeButton: NSButton = {
        let b = PUIFirstMouseButton(title: timeRemainingPlaceholder, target: self, action: #selector(toggleTrailingTimeLabelMode))

        b.contentTintColor = .timeLabel
        b.isBordered = false
        b.alignment = .right
        b.font = .monospacedDigitSystemFont(ofSize: 13, weight: .regular)

        return b
    }()

    private lazy var fullScreenButton: NSView = {
        let b = PUIVibrantButton(frame: .zero)
        b.button.image = .PUIFullScreen
        b.button.target = self
        b.button.action = #selector(toggleFullscreen)
        b.button.toolTip = "Toggle full screen"
        return b
    }()

    private lazy var volumeButton: NSButton = {
        let b = PUIFirstMouseButton(frame: .zero)

        b.image = .PUIVolume3
        b.font = NSFont.wwdcRoundedSystemFont(ofSize: 16, weight: .medium)
        b.target = self
        b.action = #selector(toggleMute)
        b.heightAnchor.constraint(equalToConstant: 24).isActive = true
        b.widthAnchor.constraint(equalToConstant: 24).isActive = true
        b.title = ""
        b.isBordered = false
        (b.cell as? NSButtonCell)?.imageScaling = .scaleNone

        return b
    }()

    fileprivate lazy var volumeSlider: NSSlider = {
        let s = NSSlider(frame: .zero)

        s.widthAnchor.constraint(equalToConstant: 88).isActive = true
        s.isContinuous = true
        s.target = self
        s.minValue = 0
        s.maxValue = 1
        s.controlSize = .small
        s.action = #selector(volumeSliderAction)

        return s
    }()

    private lazy var subtitlesButton: NSControl = {
        let b = PUIButton(frame: .zero)

        b.image = .PUISubtitles
        b.target = self
        b.action = #selector(showSubtitlesMenu)
        b.toolTip = "Subtitles"

        return b
    }()

    fileprivate lazy var playButton: PUIButton = {
        let b: PUIButton
        if shouldAdoptLiquidGlass {
            var metrics = PUIControlMetrics.large
            metrics.glass = .clear
            b = PUIButton(metrics: metrics)
        } else {
            b = PUIButton(metrics: .large)
        }

        b.isToggle = true
        b.image = .PUIPlay
        b.alternateImage = .PUIPause
        b.tintColor = .labelColor
        b.activeTintColor = .labelColor
        b.target = self
        b.action = #selector(togglePlaying)
        b.toolTip = "Play/pause"

        return b
    }()

    private lazy var backButton: PUIButton = {
        let b: PUIButton
        if shouldAdoptLiquidGlass {
            var metrics = PUIControlMetrics.medium
            metrics.glass = .clear
            metrics.padding = 5
            b = PUIButton(metrics: metrics)
        } else {
            b = PUIButton(frame: .zero)
        }
        b.image = .PUIBack15s
        b.target = self
        b.action = #selector(goBackInTime)
        b.toolTip = "Go back 15s"

        return b
    }()

    private lazy var forwardButton: PUIButton = {
        let b: PUIButton
        if shouldAdoptLiquidGlass {
            var metrics = PUIControlMetrics.medium
            metrics.glass = .clear
            metrics.padding = 5
            b = PUIButton(metrics: metrics)
        } else {
            b = PUIButton(frame: .zero)
        }

        b.image = .PUIForward15s
        b.target = self
        b.action = #selector(goForwardInTime)
        b.toolTip = "Go forward 15s"

        return b
    }()

    fileprivate lazy var speedButton = PUIPlaybackSpeedToggle(frame: .zero)

    private lazy var addAnnotationButton: NSControl = {
        let b = PUIButton(frame: .zero)

        b.image = .PUIAnnotation
        b.target = self
        b.action = #selector(addAnnotation)
        b.toolTip = "Add bookmark"
        b.metrics = .medium

        return b
    }()

    private lazy var pipButton: StatefulControl = {
        let b = PUIButton(frame: .zero)

        b.isToggle = true
        b.image = AVPictureInPictureController.pictureInPictureButtonStartImage
        b.alternateImage = AVPictureInPictureController.pictureInPictureButtonStopImage
        b.target = self
        b.action = #selector(togglePip)
        b.toolTip = "Toggle picture in picture"
        b.isEnabled = false
        b.metrics = .medium

        return b
    }()

    private lazy var routeButton: NSView = {
        let b = PUIButton(frame: .zero)

        b.isToggle = true
        b.image = .PUIAirPlay
        b.toolTip = "AirPlay"
        b.metrics = .medium
        b.isAVRoutePickerMasquerade = true

        return b
    }()

    public private(set) lazy var videoLayoutGuide = NSLayoutGuide()

    private var topTrailingMenuTopConstraint: NSLayoutConstraint!

    private func setupControls() {
        addLayoutGuide(videoLayoutGuide)
        let playerView = NSView()
        playerView.translatesAutoresizingMaskIntoConstraints = false
        playerView.wantsLayer = true
        playerView.layer = playerLayer
        playerLayer.backgroundColor = .clear
        addSubview(playerView)
        playerView.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
        playerView.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true
        playerView.topAnchor.constraint(equalTo: topAnchor).isActive = true
        playerView.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true

        // Volume controls
        let volumeControlsContainerView = NSStackView(views: [volumeButton, volumeSlider])
        self.volumeControlsContainerView = volumeControlsContainerView

        volumeControlsContainerView.orientation = .horizontal
        volumeControlsContainerView.spacing = 6
        volumeControlsContainerView.alignment = .centerY

        // Center Buttons
        let centerButtonsContainerView = NSStackView(frame: bounds)
        self.centerButtonsContainerView = centerButtonsContainerView

        // Leading controls (volume, subtitles)
        centerButtonsContainerView.addView(volumeButton, in: .leading)
        centerButtonsContainerView.addView(volumeSlider, in: .leading)
        centerButtonsContainerView.addView(subtitlesButton, in: .leading)

        centerButtonsContainerView.setCustomSpacing(6, after: volumeButton)

        // Center controls (play, forward, backward)
        centerButtonsContainerView.addView(backButton, in: .center)
        centerButtonsContainerView.addView(playButton, in: .center)
        centerButtonsContainerView.addView(forwardButton, in: .center)

        // Trailing controls (speed, add annotation, AirPlay, PiP)
        centerButtonsContainerView.addView(speedButton, in: .trailing)
        centerButtonsContainerView.addView(addAnnotationButton, in: .trailing)
        centerButtonsContainerView.addView(routeButton, in: .trailing)
        centerButtonsContainerView.addView(pipButton, in: .trailing)

        centerButtonsContainerView.orientation = .horizontal
        centerButtonsContainerView.spacing = 16
        centerButtonsContainerView.distribution = .gravityAreas
        centerButtonsContainerView.alignment = .centerY

        // Visibility priorities
        centerButtonsContainerView.setVisibilityPriority(.detachOnlyIfNecessary, for: volumeButton)
        centerButtonsContainerView.setVisibilityPriority(.detachOnlyIfNecessary, for: volumeSlider)
        centerButtonsContainerView.setVisibilityPriority(.detachOnlyIfNecessary, for: subtitlesButton)
        centerButtonsContainerView.setVisibilityPriority(.detachOnlyIfNecessary, for: backButton)
        centerButtonsContainerView.setVisibilityPriority(.mustHold, for: playButton)
        centerButtonsContainerView.setVisibilityPriority(.detachOnlyIfNecessary, for: forwardButton)
        centerButtonsContainerView.setVisibilityPriority(.detachOnlyIfNecessary, for: speedButton)
        centerButtonsContainerView.setVisibilityPriority(.detachOnlyIfNecessary, for: addAnnotationButton)
        centerButtonsContainerView.setVisibilityPriority(.detachOnlyIfNecessary, for: routeButton)
        centerButtonsContainerView.setVisibilityPriority(.detachOnlyIfNecessary, for: pipButton)
        centerButtonsContainerView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let timelineContainerView = NSStackView(views: [
            leadingTimeButton,
            timelineView,
            trailingTimeButton
        ])
        self.timelineContainerView = timelineContainerView
        timelineContainerView.distribution = .equalSpacing
        timelineContainerView.orientation = .horizontal
        timelineContainerView.alignment = .centerY

        // Main stack view and background scrim
        let controlsContainerView = NSStackView(views: [
            timelineContainerView,
            centerButtonsContainerView
            ])
        self.controlsContainerView = controlsContainerView

        controlsContainerView.orientation = .vertical
        controlsContainerView.spacing = 12
        controlsContainerView.distribution = .fill
        controlsContainerView.translatesAutoresizingMaskIntoConstraints = false
        controlsContainerView.wantsLayer = true
        controlsContainerView.layer?.masksToBounds = false
        controlsContainerView.layer?.zPosition = 10

        scrimContainerView = PUIScrimView(frame: controlsContainerView.bounds)
        scrimContainerView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(scrimContainerView)
        addSubview(controlsContainerView)

        /// Ensure a minimum amount of padding between the control area leading and trailing edges and the container.
        let scrimLeading = scrimContainerView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16)
        scrimLeading.priority = .defaultLow
        let scrimTrailing = scrimContainerView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16)
        scrimTrailing.priority = .defaultLow

        /// Define an absolute maximum width for the control area so that it doesn't look comically wide in full screen,
        /// set as lower priority so that it can potentially expand beyond this size if needed due to content size.
        let scrimMaxWidth = scrimContainerView.widthAnchor.constraint(lessThanOrEqualToConstant: 600)
        scrimMaxWidth.priority = .defaultLow

        NSLayoutConstraint.activate([
            scrimMaxWidth,
            scrimLeading,
            scrimTrailing,
            scrimContainerView.centerXAnchor.constraint(equalTo: centerXAnchor),
            scrimContainerView.bottomAnchor.constraint(equalTo: videoLayoutGuide.bottomAnchor, constant: -16),
            controlsContainerView.leadingAnchor.constraint(equalTo: scrimContainerView.leadingAnchor, constant: 16),
            controlsContainerView.trailingAnchor.constraint(equalTo: scrimContainerView.trailingAnchor, constant: -16),
            controlsContainerView.topAnchor.constraint(equalTo: scrimContainerView.topAnchor, constant: 16),
            controlsContainerView.bottomAnchor.constraint(equalTo: scrimContainerView.bottomAnchor, constant: -16)
        ])

        centerButtonsContainerView.leadingAnchor.constraint(equalTo: controlsContainerView.leadingAnchor).isActive = true
        centerButtonsContainerView.trailingAnchor.constraint(equalTo: controlsContainerView.trailingAnchor).isActive = true

        let topTrailingMenuContainerView = NSStackView(views: [fullScreenButton])
        self.topTrailingMenuContainerView = topTrailingMenuContainerView
        topTrailingMenuContainerView.orientation = .horizontal
        topTrailingMenuContainerView.alignment = .centerY
        topTrailingMenuContainerView.distribution = .equalSpacing
        topTrailingMenuContainerView.spacing = 30

        addSubview(topTrailingMenuContainerView)

        topTrailingMenuContainerView.trailingAnchor.constraint(equalTo: videoLayoutGuide.trailingAnchor, constant: -12).isActive = true
        updateTopTrailingMenuPosition()

        speedButton.$speed.removeDuplicates().sink { [weak self] speed in
            guard let self else { return }
            self.playbackSpeed = speed
        }
        .store(in: &uiBindings)

        speedButton.$isEditingCustomSpeed.sink { [weak self] isEditing in
            guard let self else { return }
            
            showControls(animated: false)
            resetMouseIdleTimer()
        }
        .store(in: &uiBindings)
    }

    var backAndForwardSkipDuration: BackForwardSkipDuration = .thirtySeconds {
        didSet {
            invalidateTouchBar()
        }
    }

    var goBackInTimeImage: NSImage {
        switch backAndForwardSkipDuration {
        case .fiveSeconds:
            .PUIBack5s
        case .tenSeconds:
            .PUIBack10s
        case .fifteenSeconds:
            .PUIBack15s
        case .thirtySeconds:
            .PUIBack30s
        }
    }

    var goBackInTimeDescription: String {
        "Go back \(backAndForwardSkipDuration.rawValue.formatted())s"
    }

    var goForwardInTimeImage: NSImage {
        switch backAndForwardSkipDuration {
        case .fiveSeconds:
            .PUIForward5s
        case .tenSeconds:
            .PUIForward10s
        case .fifteenSeconds:
            .PUIForward15s
        case .thirtySeconds:
            .PUIForward30s
        }
    }

    var goForwardInTimeDescription: String {
        "Go forward \(backAndForwardSkipDuration.rawValue.formatted())s"
    }

    private func configureWithAppearanceFromDelegate() {
        guard let d = appearanceDelegate else { return }

        /// We need to update based on the availability of subtitles, updating only from the delegate can result in
        /// the subtitles button becoming visible when there are no subtitles available.
        updateSubtitleSelectionMenu()

        pipButton.isHidden = !d.playerViewShouldShowPictureInPictureControl(self)
        speedButton.isHidden = !d.playerViewShouldShowSpeedControl(self)

        updateAnnotationButtonVisibility()

        let disableBackAndForward = !d.playerViewShouldShowBackAndForwardControls(self)
        backButton.isHidden = disableBackAndForward
        forwardButton.isHidden = disableBackAndForward

        backAndForwardSkipDuration = d.playerViewBackAndForwardDuration(self)
        backButton.image = goBackInTimeImage
        backButton.action = #selector(goBackInTime)
        backButton.toolTip = goBackInTimeDescription
        forwardButton.image = goForwardInTimeImage
        forwardButton.action = #selector(goForwardInTime)
        forwardButton.toolTip = goForwardInTimeDescription

        fullScreenButton.isHidden = !d.playerViewShouldShowFullScreenButton(self)
        timelineView.isHidden = !d.playerViewShouldShowTimelineView(self)
    }

    private func updateAnnotationButtonVisibility() {
        defer { validateAnnotationButton() }

        guard let d = appearanceDelegate else { return }

        addAnnotationButton.isHidden = !d.playerViewShouldShowAnnotationControls(self)
    }

    private func validateAnnotationButton() {
        let timestamp = self.currentTimestamp
        let tooCloseForComfort = timelineView.annotations.contains(where: { $0.isValid && abs($0.timestamp - timestamp) < 30 })
        self.addAnnotationButton.isEnabled = !tooCloseForComfort
    }

    private var isDominantViewInWindow: Bool {
        guard let contentView = window?.contentView else { return false }
        guard contentView != self else { return true }

        return bounds.height >= contentView.bounds.height
    }

    private func updateTopTrailingMenuPosition() {
        guard !shouldAdoptLiquidGlass else {
            return
        }
        let topConstant: CGFloat = isDominantViewInWindow ? 34 : 12

        if topTrailingMenuTopConstraint == nil {
            topTrailingMenuTopConstraint = topTrailingMenuContainerView.topAnchor.constraint(equalTo: videoLayoutGuide.topAnchor, constant: topConstant)
            topTrailingMenuTopConstraint.isActive = true
        } else {
            topTrailingMenuTopConstraint.constant = topConstant
        }
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

        player.volume = Float(volumeSlider.doubleValue)
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
        player?.rate = 0
    }

    @IBAction public func play(_ sender: Any?) {
        guard isEnabled else { return }

        if player?.error != nil
            || player?.currentItem?.error != nil,
            let asset = player?.currentItem?.asset as? AVURLAsset {

            // reset the player on error
            player?.replaceCurrentItem(with: AVPlayerItem(asset: AVURLAsset(url: asset.url)))
        }

        guard let player = player else { return }
        if player.hasFinishedPlaying {
            seek(to: 0)
        }

        player.rate = playbackSpeed.rawValue
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
        modifyCurrentTime(with: backAndForwardSkipDuration.rawValue, using: CMTimeSubtract)
    }

    @IBAction public func goForwardInTime(_ sender: Any?) {
        modifyCurrentTime(with: backAndForwardSkipDuration.rawValue, using: CMTimeAdd)
    }

    @IBAction public func toggleSpeed(_ sender: Any?) {
        if NSEvent.modifierFlags.contains(.option) {
            playbackSpeed = playbackSpeed.previous
        } else {
            playbackSpeed = playbackSpeed.next
        }
    }

    @IBAction public func toggleTrailingTimeLabelMode(_ sender: Any?) {
        trailingLabelDisplaysDuration.toggle()
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

        /// Prevent several clicks in quick succession from creating lots of annotations at the same location.
        addAnnotationButton.isEnabled = false

        let timestamp = Double(CMTimeGetSeconds(player.currentTime()))

        delegate?.playerViewDidSelectAddAnnotation(self, at: timestamp)
    }

    @IBAction public func togglePip(_ sender: NSView?) {
        if isInPictureInPictureMode {
            pipController?.stopPictureInPicture()
        } else {
            pipController?.startPictureInPicture()
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

        player?.seek(to: time)
    }

    private func invalidateTouchBar(destructive: Bool = false) {
        touchBarController.invalidate(destructive)
    }

    // MARK: - Subtitles

    private var subtitlesMenu: NSMenu?
    private var subtitlesGroup: AVMediaSelectionGroup?

    @MainActor
    private func updateSubtitleSelectionMenu(subtitlesGroup: AVMediaSelectionGroup?) {
        guard let subtitlesGroup else {
            subtitlesButton.isHidden = true
            return
        }

        self.subtitlesGroup = subtitlesGroup

        let hideSubtitlesButton = !(appearanceDelegate?.playerViewShouldShowSubtitlesControl(self) ?? true)

        subtitlesButton.isHidden = hideSubtitlesButton

        let menu = NSMenu()

        subtitlesGroup.options.forEach { option in
            let item = NSMenuItem(title: option.displayName, action: #selector(didSelectSubtitleOption), keyEquivalent: "")
            item.representedObject = option
            item.target = self

            menu.addItem(item)
        }

        subtitlesMenu = menu
    }

    private func updateSubtitleSelectionMenu() {
        if let appearanceDelegate {
            guard appearanceDelegate.playerViewShouldShowSubtitlesControl(self) else {
                self.subtitlesButton.isHidden = true
                return
            }
        }

        guard let subtitlesGroup else { return }
        
        updateSubtitleSelectionMenu(subtitlesGroup: subtitlesGroup)
    }

    @objc fileprivate func didSelectSubtitleOption(_ sender: NSMenuItem) {
        guard let subtitlesGroup = subtitlesGroup else { return }
        guard let option = sender.representedObject as? AVMediaSelectionOption else { return }

        // reset all item's states
        sender.menu?.items.forEach({ $0.state = .off })

        // The current language was clicked again, turn subtitles off
        if option.extendedLanguageTag == player?.currentItem?.currentMediaSelection.selectedMediaOption(in: subtitlesGroup)?.extendedLanguageTag {
            player?.currentItem?.select(nil, in: subtitlesGroup)
            return
        }

        player?.currentItem?.select(option, in: subtitlesGroup)
        sender.state = .on
    }

    @IBAction func showSubtitlesMenu(_ sender: PUIButton) {
        subtitlesMenu?.popUp(positioning: nil, at: .zero, in: sender)
    }

    // MARK: - Key commands

    private var keyDownEventMonitor: Any?

    private enum KeyCommands {
        case spaceBar
        case leftArrow
        case rightArrow
        case minus
        case lessThan
        case plus
        case greaterThan
        case j
        case k
        case l

        static func fromEvent(_ event: NSEvent) -> KeyCommands? {
            // `keyCode` and `charactersIgnoringModifiers` both will raise exceptions if called on
            // events that are not key events
            guard event.type == .keyDown else { return nil }

            switch event.keyCode {
            case 123: return .leftArrow
            case 124: return .rightArrow
            default: break
            }

            // Correctly support keyboard localization, different keyboard layouts produce different
            // characters for the same `keyCode`
            guard let character = event.charactersIgnoringModifiers else {
                return nil
            }

            switch character {
            case " ": return .spaceBar
            case "-": return .minus
            case "<": return .lessThan
            case "+": return .plus
            case ">": return .greaterThan
            case "j": return .j
            case "k": return .k
            case "l": return .l
            default: return nil
            }
        }
    }

    public var isEnabled = true {
        didSet {
            guard isEnabled != oldValue else { return }
            if !isEnabled { hideControls(animated: true) }
        }
    }

    private func startMonitoringKeyEvents() {
        #if DEBUG
        /// I was having weird crashes in previews related to key event monitoring...
        guard !ProcessInfo.isSwiftUIPreview else { return }
        #endif
        
        if keyDownEventMonitor != nil {
            stopMonitoringKeyEvents()
        }

        keyDownEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [unowned self] event in
            guard self.isEnabled else { return event }
            
            guard let command = KeyCommands.fromEvent(event) else {
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
 
            case .minus, .lessThan:
                self.reduceSpeed()
                return nil
 
            case .plus, .greaterThan:
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

    private let pipController: AVPictureInPictureController?
    private var pipPossibleObservation: Any?

    // MARK: - Visibility management

    fileprivate var canHideControls: Bool {
        guard let player = player else { return false }

        guard isPlaying else { return false }
        guard player.status == .readyToPlay else { return false }
        guard let window = window else { return false }
        guard window.isOnActiveSpace && window.isVisible else { return false }

        guard !timelineView.isEditingAnnotation else { return false }

        guard !speedButton.isEditingCustomSpeed else { return false }

        let windowMouseRect = window.convertFromScreen(NSRect(origin: NSEvent.mouseLocation, size: CGSize(width: 1, height: 1)))
        let viewMouseRect = convert(windowMouseRect, from: nil)

        // don't hide the controls when the mouse is over them
        if shouldAdoptLiquidGlass {
            return hitTest(CGPoint(x: viewMouseRect.minX, y: viewMouseRect.midY)) == controlsContainerView || !viewMouseRect.intersects(controlsContainerView.frame)
        } else {
            return !viewMouseRect.intersects(controlsContainerView.frame)
        }
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
        hideToolbarItems()
    }

    private func hideToolbarItems() {
        guard shouldAdoptLiquidGlass, let window else { return }
        let windowMouseLocation = window.convertPoint(fromScreen: NSEvent.mouseLocation)
        let hideItems = !isMouseInToolbarArea(windowMouseLocation)
        window.toolbar?.items.filter({
            ["wwdc.sidebar.search", "wwdc.main.centered.tab", "wwdc.main.download"].contains($0.itemIdentifier.rawValue)
        }).forEach {
            if #available(macOS 15.0, *) {
                $0.isHidden = hideItems
            } else {
                // Fallback on earlier versions
            }
        }
    }

    private func showControls(animated: Bool) {
        NSCursor.unhide()

        guard isEnabled else { return }

        setControls(opacity: 1, animated: animated)
        showToolbarItems(hidePiPItem: false, window: window)
    }

    private func showToolbarItems(hidePiPItem: Bool, window: NSWindow?) {
        guard shouldAdoptLiquidGlass, let window else { return }
        window.toolbar?.items.filter({
            ["wwdc.main.centered.tab", "wwdc.main.download"].contains($0.itemIdentifier.rawValue)
        }).forEach {
            if #available(macOS 15.0, *) {
                $0.isHidden = false
            } else {
                // Fallback on earlier versions
            }
        }

        window.toolbar?.items.filter({
            ["wwdc.sidebar.search"].contains($0.itemIdentifier.rawValue)
        }).forEach {
            if #available(macOS 15.0, *) {
                $0.isHidden = hidePiPItem
            } else {
                // Fallback on earlier versions
            }
        }

    }

    private func setControls(opacity: CGFloat, animated: Bool) {
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = animated ? 0.4 : 0.0

            scrimContainerView.animator().alphaValue = opacity
            controlsContainerView.animator().alphaValue = opacity
            topTrailingMenuContainerView.animator().alphaValue = opacity
            dimmingView?.animator().alphaValue = opacity
        }, completionHandler: nil)
    }

    public override func viewWillMove(toWindow newWindow: NSWindow?) {

        NotificationCenter.default.removeObserver(self, name: NSWindow.willEnterFullScreenNotification, object: window)
        NotificationCenter.default.removeObserver(self, name: NSWindow.willExitFullScreenNotification, object: window)
        NotificationCenter.default.removeObserver(self, name: NSWindow.didResignMainNotification, object: window)
        NotificationCenter.default.removeObserver(self, name: NSWindow.didBecomeMainNotification, object: window)

        NotificationCenter.default.addObserver(self, selector: #selector(windowWillEnterFullScreen), name: NSWindow.willEnterFullScreenNotification, object: newWindow)
        NotificationCenter.default.addObserver(self, selector: #selector(windowWillExitFullScreen), name: NSWindow.willExitFullScreenNotification, object: newWindow)
        NotificationCenter.default.addObserver(self, selector: #selector(windowDidExitFullScreen), name: NSWindow.didExitFullScreenNotification, object: newWindow)
        NotificationCenter.default.addObserver(self, selector: #selector(windowDidResignMain), name: NSWindow.didResignMainNotification, object: newWindow)
        NotificationCenter.default.addObserver(self, selector: #selector(windowDidBecomeMain), name: NSWindow.didBecomeMainNotification, object: newWindow)
        showToolbarItems(hidePiPItem: newWindow == nil, window: newWindow ?? window)
    }

    public override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()

        resetMouseIdleTimer()
        updateTopTrailingMenuPosition()

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

    private var isTransitioningFromFullScreenPlayback = false
    private var currentDetachedStatus: DetachedPlaybackStatus?

    public func resumeDetachedStatusIfNeeded() {
        guard let currentDetachedStatus else { return }
        appearanceDelegate?.dismissDetachedStatus(currentDetachedStatus, for: self) // this gives the delegate the chance to reset some state variables
        appearanceDelegate?.presentDetachedStatus(currentDetachedStatus, for: self)

    }

    @objc private func windowWillEnterFullScreen() {
        guard window is PUIPlayerWindow else { return }

        let status = DetachedPlaybackStatus.fullScreen.snapshot(using: snapshotClosure)
        appearanceDelegate?.presentDetachedStatus(status, for: self)
        currentDetachedStatus = status

        fullScreenButton.isHidden = true
        updateTopTrailingMenuPosition()
    }

    @objc private func windowWillExitFullScreen() {
        guard window is PUIPlayerWindow else { return }

        /// Set this because it's not safe to check for our window's class in `windowDidExitFullScreen`.
        isTransitioningFromFullScreenPlayback = true

        /// The transition looks nicer if there's no background color, otherwise the player looks like it attaches
        /// to the whole shelf area with black bars depending on the aspect ratio.
        backgroundColor = .clear
        
        if let d = appearanceDelegate {
            fullScreenButton.isHidden = !d.playerViewShouldShowFullScreenButton(self)
        }

        updateTopTrailingMenuPosition()
    }

    @objc private func windowDidExitFullScreen() {
        guard isTransitioningFromFullScreenPlayback else { return }
        
        isTransitioningFromFullScreenPlayback = false

        /// Restore solid black background after finishing exit full screen transition.
        backgroundColor = .black

        /// The detached status presentation takes care of leaving a black background before we finish the full screen transition.
        appearanceDelegate?.dismissDetachedStatus(.fullScreen, for: self)
        currentDetachedStatus = nil
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

    private func isMouseEventInTimelineArea(_ event: NSEvent) -> Bool {
        isPointInsideTimelineArea(convert(event.locationInWindow, from: nil))
    }

    private func isMouseInToolbarArea(_ mouseLocationInWindow: NSPoint) -> Bool {
        let viewMouseLocation = convert(mouseLocationInWindow, from: nil)
        let topRect = CGRect(x: controlsContainerView.safeAreaRect.minX, y: controlsContainerView.safeAreaRect.maxY, width: controlsContainerView.safeAreaRect.width, height: controlsContainerView.safeAreaInsets.top)
        return topRect.contains(viewMouseLocation)
    }

    private func isPointInsideTimelineArea(_ pointInViewCoordinates: CGPoint) -> Bool {
        let point = convert(pointInViewCoordinates, to: timelineView)
        return timelineView.hoverBounds.contains(point)
    }

    public override func mouseMoved(with event: NSEvent) {
        showControls(animated: true)
        resetMouseIdleTimer()

        super.mouseMoved(with: event)

        if isMouseEventInTimelineArea(event) {
            /// We don't want timeline hover activation when the app is not active.
            guard NSApp.isActive else { return }

            if !timelineView.hasMouseInside {
                UILog("🐭 Sending mouse entered to timeline view")

                timelineView.mouseEntered(with: event)
            }
            timelineView.mouseMoved(with: event)
        } else {
            if timelineView.hasMouseInside {
                UILog("🐭 Sending mouse exited to timeline view")

                timelineView.mouseExited(with: event)
            }
        }
        if shouldAdoptLiquidGlass, isMouseInToolbarArea(event.locationInWindow) {
            hideControls(animated: true)
        }
    }

    public override func mouseExited(with event: NSEvent) {
        resetMouseIdleTimer(start: false)

        hideControls(animated: true)

        super.mouseExited(with: event)
    }

    public override var acceptsFirstResponder: Bool {
        return true
    }

    /// Dynamically modifying the return value for this doesn't work reliably, and we don't want window dragging
    /// when the cursor is inside the expanded timeline view area, so window drag is handled in `mouseDown`.
    public override var mouseDownCanMoveWindow: Bool { false }

    public override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        guard let event else { return true }

        if event.type == .leftMouseDown {
            guard !isMouseEventInTimelineArea(event) else {
                UILog("🐭 Rejecting first mouse down event because it's within the timeline area")
                return false
            }
            return true
        } else {
            return true
        }
    }

    public override func mouseDown(with event: NSEvent) {
        guard let window else { return }

        /// This is important so that clicking outside the custom playback speed editor closes the editor.
        window.makeFirstResponder(self)

        if timelineView.hasMouseInside, isMouseEventInTimelineArea(event) {
            UILog("🐭 Sending mouse down to timeline view")
            timelineView.mouseDown(with: event)
            return
        }

        if event.type == .leftMouseDown && event.clickCount == 2 {
            toggleFullscreen(self)
        } else {
            /// `mouseDownCanMoveWindow` is `false`, so drag the window manually.
            /// Once we reach here, we've guaranteed that the cursor is not inside the timeline view area.
            window.performDrag(with: event)
        }
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

        player?.seek(to: time)
    }

    func timelineViewDidFinishInteractiveSeek() {
        if wasPlayingBeforeStartingInteractiveSeek {
            play(nil)
        }
    }

    func timelineViewFloatingTimeIndicatorDidUpdate(at timestamp: Double?, suggestedFrame: CGRect?, isHidden: Bool) {
        if let suggestedFrame {
            let localeFrame = convert(suggestedFrame, from: timelineView)
            floatingTimestampView?.frame = localeFrame
        }
        if let text = timestamp.flatMap(String.init(timestamp:)) {
            floatingTimestampModel?.text = text
        }
        floatingTimestampModel?.setIsHidden(isHidden)
    }
}

// MARK: - PiP delegate

extension PUIPlayerView: AVPictureInPictureControllerDelegate {

    private var snapshotClosure: PUISnapshotClosure {
        { [weak self] completion in
            guard let self else {
                completion(nil)
                return
            }
            snapshotPlayer(completion: completion)
        }
    }

    // Start

    public func pictureInPictureControllerWillStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        delegate?.playerViewWillEnterPictureInPictureMode(self)

        let status = DetachedPlaybackStatus.pictureInPicture.snapshot(using: snapshotClosure)
        appearanceDelegate?.presentDetachedStatus(status, for: self)
        currentDetachedStatus = status
    }

    public func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        fullScreenButton.isHidden = true
        pipButton.state = .on

        invalidateTouchBar()
    }

    public func pictureInPictureController(
        _ pictureInPictureController: AVPictureInPictureController,
        failedToStartPictureInPictureWithError error: Error
    ) {
        log.error("Failed to start PiP \(error, privacy: .public)")
    }

    // Stop

    // Called 1st
    public func pictureInPictureControllerWillStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {

    }

    // Called 2nd, not called when the exit button is pressed
    // TODO: The restore button doesn't attempt to do a restoration if the source view is no longer in a window
    public func pictureInPictureController(
        _ pictureInPictureController: AVPictureInPictureController,
        restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void
    ) {
        delegate?.playerWillRestoreUserInterfaceForPictureInPictureStop(self)

        if !NSApp.isActive {
            NSApp.activate(ignoringOtherApps: true)
        }

        if let window = lastKnownWindow {
            window.makeKeyAndOrderFront(pictureInPictureController)

            if window.isMiniaturized {
                window.deminiaturize(nil)
            }
        }

        fullScreenButton.isHidden = false

        completionHandler(true)
    }

    // Called Last
    public func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        appearanceDelegate?.dismissDetachedStatus(.pictureInPicture, for: self)
        currentDetachedStatus = nil
        pipButton.state = .off
        invalidateTouchBar()
    }
}

@available(macOS 26.0, *)
private extension PUIPlayerView {
    private func setupTahoeControls() {
        let playerView = NSView()
        playerView.translatesAutoresizingMaskIntoConstraints = false
        playerView.wantsLayer = true
        playerView.layer = playerLayer
        playerLayer.backgroundColor = .clear

        let extensionView = playerView.backgroundExtensionEffect(reflect: .leading)

        addSubview(extensionView)
        let dimmingView = NSView()
        dimmingView.translatesAutoresizingMaskIntoConstraints = false
        dimmingView.wantsLayer = true
        dimmingView.layer?.backgroundColor = CGColor(red: 0, green: 0, blue: 0, alpha: 0.3)
        dimmingView.alphaValue = 0
        self.dimmingView = dimmingView
        addSubview(dimmingView)
        NSLayoutConstraint.activate([
            extensionView.topAnchor.constraint(equalTo: topAnchor),
            extensionView.leadingAnchor.constraint(equalTo: leadingAnchor),
            extensionView.bottomAnchor.constraint(equalTo: bottomAnchor),
            extensionView.trailingAnchor.constraint(equalTo: trailingAnchor),
            dimmingView.topAnchor.constraint(equalTo: topAnchor),
            dimmingView.leadingAnchor.constraint(equalTo: leadingAnchor),
            dimmingView.bottomAnchor.constraint(equalTo: bottomAnchor),
            dimmingView.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])

        scrimContainerView = NSView() // full content
        scrimContainerView.translatesAutoresizingMaskIntoConstraints = false

        controlsContainerView = scrimContainerView // alias
        topTrailingMenuContainerView = NSView() // placeholder

        let scrimMarginGuide = NSLayoutGuide()
        scrimContainerView.addLayoutGuide(scrimMarginGuide)
        addSubview(scrimContainerView)

        NSLayoutConstraint.activate([
            scrimContainerView.topAnchor.constraint(equalTo: topAnchor),
            scrimContainerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrimContainerView.bottomAnchor.constraint(equalTo: bottomAnchor),
            scrimContainerView.trailingAnchor.constraint(equalTo: trailingAnchor),

            scrimMarginGuide.topAnchor.constraint(equalTo: scrimContainerView.safeAreaLayoutGuide.topAnchor, constant: 16),
            scrimMarginGuide.leadingAnchor.constraint(equalTo: scrimContainerView.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            scrimMarginGuide.bottomAnchor.constraint(equalTo: scrimContainerView.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            scrimMarginGuide.trailingAnchor.constraint(equalTo: scrimContainerView.safeAreaLayoutGuide.trailingAnchor, constant: -16)
        ])

        // Volume controls
        volumeButton = PUIFirstMouseButton(image: NSImage(systemSymbolName: "speaker.wave.3.fill", variableValue: 1, accessibilityDescription: "Volume")!, target: self, action: #selector(toggleMute))
        volumeButton.isBordered = false
        volumeButton.contentTintColor = .white.withAlphaComponent(0.9)
        volumeButton.imageScaling = .scaleNone
        volumeSlider.controlSize = .mini
        volumeSlider.trackFillColor = .white.withAlphaComponent(0.9)

        let volumeControlsContainerView = NSView.horizontalGlassContainer(.clear, tint: .black.opacity(0.7), paddingEdge: .horizontal, padding: 5, spacing: 2, groups: [[volumeButton, volumeSlider]])
        self.volumeControlsContainerView = volumeControlsContainerView

        let volumeGlass = volumeControlsContainerView.glassCapsuleEffect(.clear, tint: .black.opacity(0.7))
        volumeGlass.translatesAutoresizingMaskIntoConstraints = false
        scrimContainerView.addSubview(volumeGlass, positioned: .below, relativeTo: timelineContainerView)
        NSLayoutConstraint.activate([
            volumeGlass.leadingAnchor.constraint(equalTo: scrimMarginGuide.leadingAnchor),
            volumeGlass.bottomAnchor.constraint(equalTo: scrimMarginGuide.bottomAnchor),
            volumeGlass.heightAnchor.constraint(equalToConstant: 30)
        ])

        let subtitlesButton = PUIFirstMouseButton(image: .PUISubtitles.withPlayerMetrics(.medium), target: self, action: #selector(showSubtitlesMenu))
        subtitlesButton.toolTip = "Subtitles"
        self.subtitlesButton = subtitlesButton

        let addAnnotationButton = PUIFirstMouseButton(image: .PUIAnnotation.withPlayerMetrics(.medium), target: self, action: #selector(addAnnotation))
        addAnnotationButton.toolTip = "Add bookmark"
        self.addAnnotationButton = addAnnotationButton

        let fullScreenButton = PUIFirstMouseButton(image: .PUIFullScreen.withPlayerMetrics(.medium), target: self, action: #selector(toggleFullscreen))
        fullScreenButton.toolTip = "Toggle full screen"
        self.fullScreenButton = fullScreenButton

        let pipButton = PUIFirstMouseButton(image: AVPictureInPictureController.pictureInPictureButtonStartImage.withPlayerMetrics(.medium), target: self, action: #selector(togglePip))
        pipButton.setButtonType(.toggle)
        pipButton.state = .on
        pipButton.alternateImage = AVPictureInPictureController.pictureInPictureButtonStopImage.withPlayerMetrics(.medium)
        pipButton.toolTip = "Toggle picture in picture"
        self.pipButton = pipButton

        _ = routeButton
        let picker = PUIAVRoutPickerView()
        picker.toolTip = "AirPlay"
        self.routeButton = picker

        [subtitlesButton, addAnnotationButton, fullScreenButton, pipButton].forEach {
            $0.isBordered = false
            $0.imageScaling = .scaleNone
            $0.contentTintColor = .white.withAlphaComponent(0.9)
        }

        [subtitlesButton, addAnnotationButton, fullScreenButton, pipButton, picker].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            $0.widthAnchor.constraint(equalToConstant: PUIControlMetrics.medium.controlSize).isActive = true
            $0.heightAnchor.constraint(equalToConstant: PUIControlMetrics.medium.controlSize).isActive = true
        }

        speedButton.labelColor = .white.withAlphaComponent(0.9)
        speedButton.borderWidth = 2
        speedButton.editingBorderColor = .white.withAlphaComponent(0.9)
        speedButton.editingBackgroundColor = .clear
        speedButton.cornerRadius = 10
        let bottomTrailingGroup = NSView.horizontalGlassContainer(.clear, tint: .black.opacity(0.7), padding: 5, spacing: 2, groups: [
            [subtitlesButton, addAnnotationButton, speedButton]
        ])

        bottomTrailingGroup.translatesAutoresizingMaskIntoConstraints = false
        scrimContainerView.addSubview(bottomTrailingGroup)
        NSLayoutConstraint.activate([
            bottomTrailingGroup.centerYAnchor.constraint(equalTo: volumeGlass.centerYAnchor),
            bottomTrailingGroup.trailingAnchor.constraint(equalTo: scrimMarginGuide.trailingAnchor)
        ])

        let model = PUITimelineFloatingModel()
        let glassView = NSHostingView(rootView: PUITimelineGlassFloatingView().environment(model))
        floatingTimestampView = glassView
        floatingTimestampModel = model
        glassView.frame = .zero
        addSubview(glassView)

        let topLeadingGroups = NSView.horizontalGlassContainer(.clear, tint: .black.opacity(0.7), padding: 5, spacing: 2, groups: [
            [fullScreenButton, pipButton, routeButton]
        ])
        topLeadingGroups.translatesAutoresizingMaskIntoConstraints = false
        scrimContainerView.addSubview(topLeadingGroups)
        NSLayoutConstraint.activate([
            topLeadingGroups.leadingAnchor.constraint(equalTo: scrimMarginGuide.leadingAnchor),
            topLeadingGroups.topAnchor.constraint(equalTo: scrimMarginGuide.topAnchor)
        ])

        // Timeline
        timelineView = PUITimelineView(adoptLiquidGlass: true)
        timelineView.viewDelegate = self
        let timelineContainerView = NSStackView(views: [
            leadingTimeButton,
            timelineView,
            trailingTimeButton
        ])
        [leadingTimeButton, trailingTimeButton].forEach {
            $0.contentTintColor = .white
        }
        timelineContainerView.distribution = .equalSpacing
        timelineContainerView.orientation = .horizontal
        timelineContainerView.alignment = .centerY
        self.timelineContainerView = timelineContainerView

        scrimContainerView.addSubview(timelineContainerView)
        timelineContainerView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            timelineContainerView.leadingAnchor.constraint(equalTo: scrimMarginGuide.leadingAnchor),
            timelineContainerView.bottomAnchor.constraint(equalTo: bottomTrailingGroup.topAnchor, constant: -12),
            timelineContainerView.trailingAnchor.constraint(equalTo: scrimMarginGuide.trailingAnchor)
        ])

        // Center controls (play, forward, backward)
        [backButton, playButton, forwardButton].forEach {
            scrimContainerView.addSubview($0)
            $0.translatesAutoresizingMaskIntoConstraints = false
            $0.centerYAnchor.constraint(equalTo: scrimContainerView.centerYAnchor).isActive = true
        }

        let spacing = CGFloat(30)
        NSLayoutConstraint.activate([
            playButton.centerXAnchor.constraint(equalTo: scrimMarginGuide.centerXAnchor),
            backButton.trailingAnchor.constraint(equalTo: playButton.leadingAnchor, constant: -spacing),
            forwardButton.leadingAnchor.constraint(equalTo: playButton.trailingAnchor, constant: spacing)
        ])

        // Center Buttons
        centerButtonsContainerView = NSView() // placeholder

        speedButton.$speed.removeDuplicates().sink { [weak self] speed in
            guard let self else { return }
            self.playbackSpeed = speed
        }
        .store(in: &uiBindings)

        speedButton.$isEditingCustomSpeed.sink { [weak self] isEditing in
            guard let self else { return }

            showControls(animated: false)
            resetMouseIdleTimer()
        }
        .store(in: &uiBindings)
    }
}

#if DEBUG
struct PUIPlayerView_Previews: PreviewProvider {
    static var previews: some View {
        PUIPlayerViewPreviewWrapper()
            .frame(minWidth: 200, maxWidth: .infinity, minHeight: 200, maxHeight: .infinity)
    }
}

private struct PUIPlayerViewPreviewWrapper: NSViewRepresentable {
    typealias NSViewType = PUIPlayerView

    func makeNSView(context: Context) -> PUIPlayerView {
        let player = AVPlayer(url: .previewVideoURL)
        let view = PUIPlayerView(player: player, shouldAdoptLiquidGlass: true)
        player.seek(to: CMTimeMakeWithSeconds(30, preferredTimescale: 9000))
        return view
    }

    func updateNSView(_ nsView: PUIPlayerView, context: Context) {

    }
}

import UniformTypeIdentifiers

private extension URL {
    static let bipbop = URL(string: "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8")!

    static let previewVideoURL: URL = {
        let dirURL = URL(fileURLWithPath: NSHomeDirectory() + "/Library/Application Support/WWDC")
        guard let enumerator = FileManager.default.enumerator(at: dirURL, includingPropertiesForKeys: [.contentTypeKey], options: [.skipsHiddenFiles], errorHandler: nil) else {
            return bipbop
        }

        while let url = enumerator.nextObject() as? URL {
            let isMovie = (try? url.resourceValues(forKeys: [.contentTypeKey]))?.contentType?.conforms(to: .movie) == true
            guard isMovie else { continue }
            return url
        }

        return bipbop
    }()
}
#endif

