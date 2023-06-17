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
import AVKit
import Combine
import SwiftUI

public final class PUIPlayerView: NSView, ObservableObject {

    public struct State: Hashable {
        static let placeholderTime = "--:--"

        public enum Feature: Int, CaseIterable {
            case PiP
            case back
            case forward
            case speed
            case addAnnotation
            case enterFullScreen
            case timeline
            case subtitles
        }

        public enum PlaybackState: Int {
            case idle
            case stalled
            case paused
            case playing
        }

        /// The current time in the AVPlayer.
        public var currentTime: CMTime = .zero
        /// The current time set by the user.
        public var userTime: CMTime = .zero
        public internal(set) var duration: CMTime = .zero
        public internal(set) var formattedCurrentTime = Self.placeholderTime
        public internal(set) var formattedTimeRemaining = Self.placeholderTime
        public var playbackProgress: Double = 0
        public internal(set) var isPiPAvailable = false
        public var playbackState: PlaybackState = .idle
        public var speed: PUIPlaybackSpeed = .normal
        public var volume: Float = 1
        public internal(set) var subtitles: AVMediaSelectionGroup?
        var bufferedSegments = Set<PUIBufferSegment>()
        public var features = Set<Feature>(Feature.allCases)
        public var backForwardSkipInterval = 15

        func has(_ feature: Feature) -> Bool { features.contains(feature) }
        mutating func enable(_ feature: Feature) { features.insert(feature) }
        mutating func disable(_ feature: Feature) { features.remove(feature) }
    }

    enum PiPEvent: Int {
        case detach
        case attach
        case stop
    }

    let pictureInPictureEvent = PassthroughSubject<PiPEvent, Never>()

    @Published public var state = State()

    private let log = OSLog(subsystem: "PlayerUI", category: "PUIPlayerView")
    private var cancellables: Set<AnyCancellable> = []
    private var stateCancellables: Set<AnyCancellable> = []

    // MARK: - Public API

    public weak var timelineDelegate: PUITimelineDelegate?
    public weak var delegate: PUIPlayerViewDelegate?

    public var isInPictureInPictureMode: Bool { pipController?.isPictureInPictureActive == true }

    public weak var appearanceDelegate: PUIPlayerViewAppearanceDelegate? {
        didSet {
            invalidateAppearance()
        }
    }

    public var annotations: [PUITimelineAnnotation] {
        get {
            return sortedAnnotations
        }
        set {
            sortedAnnotations = newValue.filter({ $0.isValid }).sorted(by: { $0.timestamp < $1.timestamp })
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
        setupUI()
    }

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public var nowPlayingInfo: PUINowPlayingInfo? {
        didSet {
            nowPlayingCoordinator?.basicNowPlayingInfo = nowPlayingInfo
        }
    }

    public var isPlaying: Bool { isInternalPlayerPlaying }

    public var isInternalPlayerPlaying: Bool {
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
            state.speed = playbackSpeed

            invalidateTouchBar()
        }
    }

    public var hideAllControls: Bool = false {
        didSet {

        }
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
        if let pipController {
            pipPossibleObservation = pipController.observe(
                \AVPictureInPictureController.isPictureInPicturePossible, options: [.initial, .new]
            ) { [weak self] _, change in
                self?.state.isPiPAvailable = change.newValue ?? false
            }
            pipController.delegate = self
        } else {
            state.isPiPAvailable = false
        }

        playerLayer.player = player
        playerLayer.videoGravity = .resizeAspect

        let options: NSKeyValueObservingOptions = [.initial, .new]
        player.publisher(for: \.status, options: options).sink { [weak self] change in
            self?.playerStatusChanged()
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
            self?.state.duration = try await duration
            self?.state.subtitles = try await legible
        }

        playerTimeObserver = player.addPeriodicTimeObserver(forInterval: CMTimeMakeWithSeconds(0.5, preferredTimescale: 9000), queue: .main) { [weak self] currentTime in
            self?.playerTimeDidChange(time: currentTime)
        }

        player.allowsExternalPlayback = true

        setupNowPlayingCoordinatorIfSupported()
        setupRemoteCommandCoordinator()
        setupStateBindings()
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

    private func setupStateBindings() {
        stateCancellables.removeAll()

        Publishers.CombineLatest($state.map(\.playbackState).removeDuplicates(), $state.map(\.speed).removeDuplicates()).sink { [weak self] playbackState, speed in
            guard let self = self else { return }

            switch playbackState {
            case .playing:
                self.player?.rate = speed.rawValue
            case .paused:
                self.player?.pause()
            default:
                break
            }
        }
        .store(in: &stateCancellables)

        $state.map(\.volume).removeDuplicates().sink { [weak self] volume in
            self?.player?.volume = volume
        }
        .store(in: &stateCancellables)

        $state.map(\.userTime).removeDuplicates().dropFirst().sink { [weak self] time in
            self?.seek(to: time)
        }
        .store(in: &stateCancellables)
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

        state.bufferedSegments = Set<PUIBufferSegment>(segments)
    }

    fileprivate func updatePlayingState() {
        if isPlaying {
            state.playbackState = .playing
        } else {
            state.playbackState = .paused
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
            self.state.playbackProgress = progress

            self.updateTimeLabels()
        }
    }

    private func updateTimeLabels() {
        guard let player = player else { return }

        guard player.hasValidMediaDuration else { return }
        guard let duration = asset?.durationIfLoaded else { return }

        let time = player.currentTime()

        state.currentTime = time
        state.formattedCurrentTime = String(time: time) ?? State.placeholderTime

        let remainingTime = CMTimeSubtract(time, duration)
        state.formattedTimeRemaining = String(time: remainingTime) ?? State.placeholderTime
    }

    public override func layout() {
        updateVideoLayoutGuide()

        super.layout()
    }

    private lazy var videoLayoutGuideConstraints = [NSLayoutConstraint]()

    private func updateVideoLayoutGuide() {
        guard let videoTrack = player?.currentItem?.tracks.first(where: { $0.assetTrack?.mediaType == .video })?.assetTrack else { return }

        let videoRect = AVMakeRect(aspectRatio: videoTrack.naturalSize, insideRect: bounds)

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

    private lazy var videoLayoutGuide = NSLayoutGuide()

    private lazy var controlsContainer: NSView = {
        let v = NSView()
        v.wantsLayer = true
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private lazy var controlsHost: NSView = {
        let v = NSHostingView(rootView: PUIPlayerViewControls().environmentObject(self))
        v.wantsLayer = true
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private func setupUI() {
        addLayoutGuide(videoLayoutGuide)

        playerLayer.frame = bounds
        playerLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        layer?.addSublayer(playerLayer)

        addSubview(controlsContainer)
        NSLayoutConstraint.activate([
            controlsContainer.leadingAnchor.constraint(equalTo: videoLayoutGuide.leadingAnchor),
            controlsContainer.trailingAnchor.constraint(equalTo: videoLayoutGuide.trailingAnchor),
            controlsContainer.topAnchor.constraint(equalTo: videoLayoutGuide.topAnchor),
            controlsContainer.bottomAnchor.constraint(equalTo: videoLayoutGuide.bottomAnchor)
        ])

        controlsContainer.addSubview(controlsHost)
        NSLayoutConstraint.activate([
            controlsHost.leadingAnchor.constraint(equalTo: controlsContainer.leadingAnchor),
            controlsHost.trailingAnchor.constraint(equalTo: controlsContainer.trailingAnchor),
            controlsHost.topAnchor.constraint(equalTo: controlsContainer.topAnchor),
            controlsHost.bottomAnchor.constraint(equalTo: controlsContainer.bottomAnchor)
        ])
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

        var features = Set<State.Feature>()

        if d.playerViewShouldShowSubtitlesControl(self) { features.insert(.subtitles) }
        if d.playerViewShouldShowPictureInPictureControl(self) { features.insert(.PiP) }
        if d.playerViewShouldShowSpeedControl(self) { features.insert(.speed) }
        if d.playerViewShouldShowAnnotationControls(self) { features.insert(.addAnnotation) }
        if d.playerViewShouldShowFullScreenButton(self) { features.insert(.enterFullScreen) }
        if d.playerViewShouldShowTimelineView(self) { features.insert(.timeline) }
        if d.playerViewShouldShowBackAndForwardControls(self) {
            features.insert(.back)
            features.insert(.forward)
        }
        if d.playerViewShouldShowBackAndForward30SecondsButtons(self) {
            state.backForwardSkipInterval = 30
        } else {
            state.backForwardSkipInterval = 15
        }

        state.features = features
    }

    private var isDominantViewInWindow: Bool {
        guard let contentView = window?.contentView else { return false }
        guard contentView != self else { return true }

        return bounds.height >= contentView.bounds.height
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

    @MainActor
    private func updateSubtitleSelectionMenu(subtitlesGroup: AVMediaSelectionGroup?) {
        state.subtitles = subtitlesGroup
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
            // TODO: Commented out special handling might be important
//            guard !self.timelineView.isEditingAnnotation else { return event }

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

        return true

        // TODO: Below commented out special handling might be important
//        guard !timelineView.isEditingAnnotation else { return false }

        // TODO: Hover state comes from SwiftUI land?
//        let windowMouseRect = window.convertFromScreen(NSRect(origin: NSEvent.mouseLocation, size: CGSize(width: 1, height: 1)))
//        let viewMouseRect = convert(windowMouseRect, from: nil)
//
//        // don't hide the controls when the mouse is over them
//        return !viewMouseRect.intersects(controlsContainerView.frame)
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
        if opacity > 0 { controlsContainer.isHidden = false }

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = animated ? 0.3 : 0
            controlsContainer.animator().alphaValue = opacity
        } completionHandler: { [weak self] in
            guard let self = self else { return }
            self.controlsContainer.isHidden = opacity <= 0
        }
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
        state.disable(.enterFullScreen)
    }

    @objc private func windowWillExitFullScreen() {
        if let d = appearanceDelegate {
            if d.playerViewShouldShowFullScreenButton(self) {
                state.enable(.enterFullScreen)
            }
        }
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

}

// MARK: - PUITimelineViewDelegate

extension PUIPlayerView: PUITimelineViewDelegate {

    func timelineDidReceiveForceTouch(at timestamp: Double) {
        guard let player = player else { return }

        let timestamp = Double(CMTimeGetSeconds(player.currentTime()))

        delegate?.playerViewDidSelectAddAnnotation(self, at: timestamp)
    }

    func timelineViewWillBeginInteractiveSeek() {
        pause(nil)
    }

    func timelineViewDidSeek(to progress: Double) {
        guard let duration = asset?.duration else { return }

        let targetTime = progress * Double(CMTimeGetSeconds(duration))
        let time = CMTimeMakeWithSeconds(targetTime, preferredTimescale: duration.timescale)

        player?.seek(to: time)
    }

    func timelineViewDidFinishInteractiveSeek() {
//        if wasPlayingBeforeStartingInteractiveSeek {
//            play(nil)
//        }
    }

}

// MARK: - PiP delegate

extension PUIPlayerView: AVPictureInPictureControllerDelegate {

    // Start

    public func pictureInPictureControllerWillStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        delegate?.playerViewWillEnterPictureInPictureMode(self)

//        snapshotPlayer { [weak self] image in
//            self?.externalStatusController.snapshot = image
//        }
    }

    public func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        pictureInPictureEvent.send(.detach)

        invalidateTouchBar()
    }

    public func pictureInPictureController(
        _ pictureInPictureController: AVPictureInPictureController,
        failedToStartPictureInPictureWithError error: Error
    ) {
        os_log(.error, log: log, "Failed to start PiP \(error, privacy: .public)")
    }

    // Stop

    // Called 1st
    public func pictureInPictureControllerWillStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {

    }

    // Called 2nd, not called when the exit button is pressed
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

        pictureInPictureEvent.send(.attach)

        completionHandler(true)
    }

    // Called Last
    public func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        pictureInPictureEvent.send(.stop)

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
