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

    // MARK: - Public API

    public weak var delegate: PUIPlayerViewDelegate?

    public var isInPictureInPictureMode: Bool { pipController?.isPictureInPictureActive == true }

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

    public init(player: AVPlayer) {
        self.player = player
        if AVPictureInPictureController.isPictureInPictureSupported() {
            self.pipController = AVPictureInPictureController(contentSource: .init(playerLayer: playerLayer))
        } else {
            self.pipController = nil
        }

        super.init(frame: .zero)

        wantsLayer = true
        layer = PUIBoringLayer()
        layer?.backgroundColor = NSColor.black.cgColor

        setupPlayer(player)
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

            if playbackSpeed != oldValue, isPlaying && !isPlayingExternally {
                player.rate = playbackSpeed.rawValue
                player.seek(to: player.currentTime()) // Helps the AV sync when speeds change with the TimeDomain algorithm enabled
            }

            updatePlaybackSpeedState()

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
            log.error("Tried to register provider \(provider.name, privacy: .public) which was already registered")
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

    private var sortedAnnotations: [PUITimelineAnnotation] = []

    private var playerTimeObserver: Any?

    fileprivate var asset: AVAsset? {
        return player?.currentItem?.asset
    }

    private let playerLayer = PUIBoringPlayerLayer()

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

        player.allowsExternalPlayback = true
        routeButton.player = player

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
    }

    private func applyUserSettings(to player: AVPlayer) {
        trailingLabelDisplaysDuration = settings.trailingLabelDisplaysDuration

        player.volume = Float(settings.playerVolume)
    }

    private func playerVolumeChanged() {
        guard let player = player else { return }

        settings.playerVolume = Double(player.volume)

        if player.volume.isZero {
            volumeButton.image = .PUIVolumeMuted
            volumeButton.toolTip = "Unmute"
            volumeSlider.doubleValue = 0
        } else {
            switch player.volume {
            case 0..<0.33:
                volumeButton.image = .PUIVolume1
            case 0.33..<0.66:
                volumeButton.image = .PUIVolume2
            default:
                volumeButton.image = .PUIVolume3
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

    public override func layout() {
        updateVideoLayoutGuide()

        super.layout()
    }

    private lazy var videoLayoutGuideConstraints = [NSLayoutConstraint]()

    private var currentBounds = CGRect.zero

    private func updateVideoLayoutGuide() {
        guard let videoTrack = player?.currentItem?.tracks.first(where: { $0.assetTrack?.mediaType == .video })?.assetTrack else { return }

        guard bounds != currentBounds else { return }
        currentBounds = bounds

        let videoRect = AVMakeRect(aspectRatio: videoTrack.naturalSize, insideRect: bounds)

        guard videoRect.width.isFinite, videoRect.height.isFinite else { return }

        NSLayoutConstraint.deactivate(videoLayoutGuideConstraints)

        videoLayoutGuideConstraints = [
            videoLayoutGuide.widthAnchor.constraint(equalToConstant: videoRect.width),
            videoLayoutGuide.heightAnchor.constraint(equalToConstant: videoRect.height),
            videoLayoutGuide.centerYAnchor.constraint(equalTo: centerYAnchor),
            videoLayoutGuide.centerXAnchor.constraint(equalTo: centerXAnchor)
        ]

        NSLayoutConstraint.activate(videoLayoutGuideConstraints)
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
    private var timelineContainerView: NSStackView!

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

    private lazy var fullScreenButton: PUIVibrantButton = {
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

        b.isToggle = true
        b.image = .PUIPlay
        b.alternateImage = .PUIPause
        b.tintColor = .labelColor
        b.activeTintColor = .labelColor
        b.target = self
        b.action = #selector(togglePlaying)
        b.toolTip = "Play/pause"
        b.metrics = .large

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

    fileprivate lazy var speedButton = PUIPlaybackSpeedToggle(frame: .zero)

    private lazy var addAnnotationButton: PUIButton = {
        let b = PUIButton(frame: .zero)

        b.image = .PUIAnnotation
        b.target = self
        b.action = #selector(addAnnotation)
        b.toolTip = "Add bookmark"
        b.metrics = .medium

        return b
    }()

    private lazy var pipButton: PUIButton = {
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

    private lazy var routeButton: PUIButton = {
        let b = PUIButton(frame: .zero)

        b.isToggle = true
        b.image = .PUIAirPlay
        b.toolTip = "AirPlay"
        b.metrics = .medium
        b.isAVRoutePickerMasquerade = true

        return b
    }()

    private lazy var videoLayoutGuide = NSLayoutGuide()

    private var extrasMenuTopConstraint: NSLayoutConstraint!

    private lazy var externalStatusController = PUIExternalPlaybackStatusViewController()

    private func setupControls() {
        addLayoutGuide(videoLayoutGuide)

        externalStatusController.view.translatesAutoresizingMaskIntoConstraints = false
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

        externalStatusController.hide()

        addSubview(externalStatusController.view)
        externalStatusController.view.leadingAnchor.constraint(equalTo: videoLayoutGuide.leadingAnchor).isActive = true
        externalStatusController.view.trailingAnchor.constraint(equalTo: videoLayoutGuide.trailingAnchor).isActive = true
        externalStatusController.view.topAnchor.constraint(equalTo: videoLayoutGuide.topAnchor).isActive = true
        externalStatusController.view.bottomAnchor.constraint(equalTo: videoLayoutGuide.bottomAnchor).isActive = true

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

        timelineContainerView = NSStackView(views: [
            leadingTimeButton,
            timelineView,
            trailingTimeButton
        ])
        timelineContainerView.distribution = .equalSpacing
        timelineContainerView.orientation = .horizontal
        timelineContainerView.alignment = .centerY

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

        // Extras menu (external playback, fullscreen button)
        extrasMenuContainerView = NSStackView(views: [fullScreenButton])
        extrasMenuContainerView.orientation = .horizontal
        extrasMenuContainerView.alignment = .centerY
        extrasMenuContainerView.distribution = .equalSpacing
        extrasMenuContainerView.spacing = 30

        addSubview(extrasMenuContainerView)

        extrasMenuContainerView.trailingAnchor.constraint(equalTo: videoLayoutGuide.trailingAnchor, constant: -12).isActive = true
        updateExtrasMenuPosition()

        speedButton.$speed.removeDuplicates().sink { [weak self] speed in
            guard let self else { return }
            self.playbackSpeed = speed
        }
        .store(in: &cancellables)
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

        /// We need to update based on the availability of subtitles, updating only from the delegate can result in
        /// the subtitles button becoming visible when there are no subtitles available.
        updateSubtitleSelectionMenu()

        pipButton.isHidden = !d.playerViewShouldShowPictureInPictureControl(self)
        speedButton.isHidden = !d.playerViewShouldShowSpeedControl(self)

        let disableAnnotationControls = !d.playerViewShouldShowAnnotationControls(self)
        addAnnotationButton.isHidden = disableAnnotationControls

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
            extrasMenuTopConstraint = extrasMenuContainerView.topAnchor.constraint(equalTo: videoLayoutGuide.topAnchor, constant: topConstant)
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
        case plus
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
            case "+": return .plus
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

    private func isMouseEventInTimelineArea(_ event: NSEvent) -> Bool {
        isPointInsideTimelineArea(convert(event.locationInWindow, from: nil))
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
        externalStatusController.show()

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

        externalStatusController.hide()
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

extension PUIPlayerView: AVPictureInPictureControllerDelegate {

    // Start

    public func pictureInPictureControllerWillStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        delegate?.playerViewWillEnterPictureInPictureMode(self)

        snapshotPlayer { [weak self] image in
            self?.externalStatusController.snapshot = image
        }

        externalStatusController.providerIcon = .PUIPictureInPictureLarge.withPlayerMetrics(.large)
        externalStatusController.providerName = "Picture in Picture"
        externalStatusController.providerDescription = "Playing in Picture in Picture"
        externalStatusController.show()
    }

    public func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
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

        completionHandler(true)
    }

    // Called Last
    public func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        pipButton.state = .off
        externalStatusController.hide()
        invalidateTouchBar()
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
        let view = PUIPlayerView(player: player)
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
