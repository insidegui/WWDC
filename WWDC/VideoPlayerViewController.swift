//
//  VideoPlayerViewController.swift
//  WWDC
//
//  Created by Guilherme Rambo on 04/06/16.
//  Copyright © 2016 Guilherme Rambo. All rights reserved.
//

import Cocoa
import AVFoundation
import PlayerUI
import RxSwift
import RxCocoa
import RealmSwift
import RxRealm
import ConfCore

extension Notification.Name {
    static let HighlightTranscriptAtCurrentTimecode = Notification.Name("HighlightTranscriptAtCurrentTimecode")
}

protocol VideoPlayerViewControllerDelegate: class {

    func createBookmark(at timecode: Double, with snapshot: NSImage?)
    func createFavorite()

}

final class VideoPlayerViewController: NSViewController {

    private var disposeBag = DisposeBag()

    weak var delegate: VideoPlayerViewControllerDelegate?

    var playbackViewModel: PlaybackViewModel?

    var sessionViewModel: SessionViewModel {
        didSet {
            disposeBag = DisposeBag()

            updateUI()
            resetAppearanceDelegate()
        }
    }

    weak var player: AVPlayer! {
        didSet {
            reset(oldValue: oldValue)
        }
    }

    var playerWillExitPictureInPicture: ((PUIPiPExitReason) -> Void)?
    var playerWillExitFullScreen: (() -> Void)?

    init(player: AVPlayer, session: SessionViewModel) {
        sessionViewModel = session
        self.player = player

        super.init(nibName: nil, bundle: nil)
    }

    required public init?(coder: NSCoder) {
        fatalError("VideoPlayerViewController can't be initialized with a coder")
    }

    lazy var playerView: PUIPlayerView = {
        return PUIPlayerView(player: self.player)
    }()

    fileprivate lazy var progressIndicator: NSProgressIndicator = {
        let p = NSProgressIndicator(frame: NSRect.zero)

        p.controlSize = .regular
        p.style = .spinning
        p.isIndeterminate = true
        p.translatesAutoresizingMaskIntoConstraints = false
        p.appearance = NSAppearance(named: NSAppearance.Name(rawValue: "WhiteSpinner"))
        p.isHidden = true

        p.sizeToFit()

        return p
    }()

    override func loadView() {
        view = NSView(frame: NSRect.zero)
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.black.cgColor

        playerView.translatesAutoresizingMaskIntoConstraints = false
        playerView.frame = view.bounds
        view.addSubview(playerView)

        playerView.registerExternalPlaybackProvider(ChromeCastPlaybackProvider.self)

        playerView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        playerView.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        playerView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        playerView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true

        view.addSubview(progressIndicator)
        view.addConstraints([
            NSLayoutConstraint(item: progressIndicator, attribute: .centerX, relatedBy: .equal, toItem: view, attribute: .centerX, multiplier: 1.0, constant: 0.0),
            NSLayoutConstraint(item: progressIndicator, attribute: .centerY, relatedBy: .equal, toItem: view, attribute: .centerY, multiplier: 1.0, constant: 0.0)
            ])

        progressIndicator.layer?.zPosition = 999
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        playerView.delegate = self
        resetAppearanceDelegate()
        reset(oldValue: nil)
        updateUI()

        NotificationCenter.default.addObserver(self, selector: #selector(annotationSelected(notification:)), name: .TranscriptControllerDidSelectAnnotation, object: nil)

        NotificationCenter.default.rx.notification(.SkipBackAndForwardBy30SecondsPreferenceDidChange).observeOn(MainScheduler.instance).subscribe { _ in
            self.playerView.invalidateAppearance()
        }.disposed(by: disposeBag)
    }

    func resetAppearanceDelegate() {
        playerView.appearanceDelegate = self
    }

    func reset(oldValue: AVPlayer?) {
        if let oldPlayer = oldValue {
            if let boundaryObserver = boundaryObserver {
                oldPlayer.removeTimeObserver(boundaryObserver)
                self.boundaryObserver = nil
            }

            playerView.player = nil

            oldPlayer.pause()
            oldPlayer.cancelPendingPrerolls()
            oldPlayer.currentItem?.cancelPendingSeeks()
            oldPlayer.currentItem?.asset.cancelLoading()
        }

        setupPlayerObservers()

        playerView.player = player
        playerView.play(self)

        if let playbackViewModel = playbackViewModel {
            playerView.remoteMediaUrl = playbackViewModel.remoteMediaURL
            playerView.mediaTitle = playbackViewModel.title
            playerView.mediaPosterUrl = playbackViewModel.imageURL
            playerView.mediaIsLiveStream = playbackViewModel.isLiveStream
        }

        setupTranscriptSync()
    }

    func updateUI() {
        let bookmarks = sessionViewModel.session.bookmarks.sorted(byKeyPath: "timecode")
        Observable.shallowCollection(from: bookmarks).observeOn(MainScheduler.instance).subscribe(onNext: { [weak self] bookmarks in
            self?.playerView.annotations = bookmarks.toArray()
        }).disposed(by: disposeBag)
    }

    @objc private func annotationSelected(notification: Notification) {
        guard let (transcript, annotation) = notification.object as? (Transcript, TranscriptAnnotation) else { return }
        guard transcript.identifier == sessionViewModel.session.transcriptIdentifier else { return }

        let time = CMTimeMakeWithSeconds(annotation.timecode, preferredTimescale: 90000)
        player.seek(to: time)
    }

    var currentTime: CMTime? {
        player?.currentTime()
    }

    var isPlaying: Bool {
        guard let player = player else { return false }
        return !player.rate.isZero
    }

    func play() {
        player?.play()
    }

    func pause() {
        player?.pause()
    }

    // MARK: - Player Observation

    private var playerStatusObserver: NSKeyValueObservation?
    private var currentItemStatusObserver: NSKeyValueObservation?
    private var presentationSizeObserver: NSKeyValueObservation?
    private var currentItemObserver: NSKeyValueObservation?
    private var timeControlStatusObserver: NSKeyValueObservation?

    private func setupPlayerObservers() {

        playerStatusObserver = player.observe(\.status, options: [.initial, .new], changeHandler: { [weak self] (player, change) in
            guard let self = self else { return }
            DispatchQueue.main.async(execute: self.showPlaybackErrorIfNeeded)
        })

        timeControlStatusObserver = player.observe(\AVPlayer.timeControlStatus) { [weak self] (player, change) in
            guard let self = self else { return }
            DispatchQueue.main.async(execute: self.timeControlStatusDidChange)
        }

        currentItemObserver = player.observe(\.currentItem, options: [.initial, .new]) { [weak self] (player, change) in
            self?.presentationSizeObserver = player.currentItem?.observe(\.presentationSize, options: [.initial, .new]) { [weak self] (player, change) in
                guard let self = self else { return }
                DispatchQueue.main.async(execute: self.playerItemPresentationSizeDidChange)
            }

            self?.currentItemStatusObserver = player.currentItem?.observe(\.status) { item, _ in
                guard let self = self else { return }
                self.showPlaybackErrorIfNeeded()
            }
        }
    }

    private func playerItemPresentationSizeDidChange() {
        guard let size = player.currentItem?.presentationSize, size != NSSize.zero else { return }

        (view.window as? PUIPlayerWindow)?.aspectRatio = size
    }

    private func showPlaybackErrorIfNeeded() {

        if let error = player.error ?? player.currentItem?.error {
            WWDCAlert.show(with: error)
        }
    }

    private func timeControlStatusDidChange() {
        func showLoading() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                guard self?.player.timeControlStatus == .waitingToPlayAtSpecifiedRate else { return }
                self?.progressIndicator.startAnimation(nil)
                self?.progressIndicator.isHidden = false
            }
        }

        func hideLoading() {
            if !progressIndicator.isHidden {
                progressIndicator.stopAnimation(nil)
                progressIndicator.isHidden = true
            }
        }

        switch player.timeControlStatus {
        case .waitingToPlayAtSpecifiedRate:
            showLoading()
        case .playing, .paused:
            hideLoading()
        @unknown default:
            assertionFailure("An unexpected case was discovered on an non-frozen obj-c enum")
            hideLoading()
        }
    }

    // MARK: - Transcript sync

    private var boundaryObserver: Any?

    private func setupTranscriptSync() {
        guard let player = player else { return }
        guard let transcript = sessionViewModel.session.transcript() else { return }

        let timecodes = transcript.timecodesWithTimescale(9000)
        guard timecodes.count > 0 else { return }

        boundaryObserver = player.addBoundaryTimeObserver(forTimes: timecodes, queue: DispatchQueue.main) { [unowned self] in
            guard !transcript.isInvalidated, self.player != nil else { return }

            let ct = CMTimeGetSeconds(self.player.currentTime())
            let roundedTimecode = Transcript.roundedStringFromTimecode(ct)

            NotificationCenter.default.post(name: .HighlightTranscriptAtCurrentTimecode, object: roundedTimecode)
        }
    }

    // MARK: - Detach

    var detachedWindowController: VideoPlayerWindowController!

    func detach(forEnteringFullscreen fullscreen: Bool = false) {
        view.translatesAutoresizingMaskIntoConstraints = true

        detachedWindowController = VideoPlayerWindowController(playerViewController: self, fullscreenOnly: fullscreen, originalContainer: view.superview)
        detachedWindowController.contentViewController = self

        detachedWindowController.actionOnWindowClosed = { [weak self] in
            self?.detachedWindowController = nil
        }

        detachedWindowController.actionOnWindowWillExitFullScreen = { [weak self] in
            self?.playerWillExitFullScreen?()
        }

        detachedWindowController.showWindow(self)
    }

    deinit {
        player.removeObserver(self, forKeyPath: #keyPath(AVPlayer.currentItem.presentationSize))
        player.removeObserver(self, forKeyPath: #keyPath(AVPlayer.status))
    }

}

extension VideoPlayerViewController: PUIPlayerViewDelegate {

    func playerViewDidSelectToggleFullScreen(_ playerView: PUIPlayerView) {
        if let playerWindow = playerView.window as? PUIPlayerWindow {
            playerWindow.toggleFullScreen(self)
        } else {
            detach(forEnteringFullscreen: true)
        }
    }

    func playerViewDidSelectAddAnnotation(_ playerView: PUIPlayerView, at timestamp: Double) {
        snapshotPlayer { snapshot in
            self.delegate?.createBookmark(at: timestamp,
                                          with: snapshot.map { NSImage(cgImage: $0, size: NSSize(width: $0.width, height: $0.height)) })
        }
    }

    private func snapshotPlayer(completion: @escaping (CGImage?) -> Void) {
        playerView.snapshotPlayer(completion: completion)
    }

    func playerViewWillExitPictureInPictureMode(_ playerView: PUIPlayerView, reason: PUIPiPExitReason) {
        playerWillExitPictureInPicture?(reason)
    }

    func playerViewWillEnterPictureInPictureMode(_ playerView: PUIPlayerView) {

    }

    func playerViewDidSelectLike(_ playerView: PUIPlayerView) {
        delegate?.createFavorite()
    }

}

extension VideoPlayerViewController: PUIPlayerViewAppearanceDelegate {

    func playerViewShouldShowSubtitlesControl(_ playerView: PUIPlayerView) -> Bool {
       return true
    }

    func playerViewShouldShowPictureInPictureControl(_ playerView: PUIPlayerView) -> Bool {
       return true
    }

    func playerViewShouldShowSpeedControl(_ playerView: PUIPlayerView) -> Bool {
        return !sessionViewModel.sessionInstance.isCurrentlyLive
    }

    func playerViewShouldShowAnnotationControls(_ playerView: PUIPlayerView) -> Bool {
        return !sessionViewModel.sessionInstance.isCurrentlyLive
    }

    func playerViewShouldShowBackAndForwardControls(_ playerView: PUIPlayerView) -> Bool {
        return !sessionViewModel.sessionInstance.isCurrentlyLive
    }

    func playerViewShouldShowExternalPlaybackControls(_ playerView: PUIPlayerView) -> Bool {
        return true
    }

    func playerViewShouldShowFullScreenButton(_ playerView: PUIPlayerView) -> Bool {
        return true
    }

    func playerViewShouldShowTimelineView(_ playerView: PUIPlayerView) -> Bool {
        return !sessionViewModel.sessionInstance.isCurrentlyLive
    }

    func playerViewShouldShowTimestampLabels(_ playerView: PUIPlayerView) -> Bool {
        return !sessionViewModel.sessionInstance.isCurrentlyLive
    }

    func playerViewShouldShowBackAndForward30SecondsButtons(_ playerView: PUIPlayerView) -> Bool {
        return Preferences.shared.skipBackAndForwardBy30Seconds
    }
}

extension Transcript {

    func timecodesWithTimescale(_ timescale: Int32) -> [NSValue] {
        return annotations.map { annotation -> NSValue in
            let time = CMTimeMakeWithSeconds(annotation.timecode, preferredTimescale: timescale)

            return NSValue(time: time)
        }
    }

    class func roundedStringFromTimecode(_ timecode: Float64) -> String {
        let formatter = NumberFormatter()
        formatter.positiveFormat = "0.#"

        return formatter.string(from: NSNumber(value: timecode)) ?? "0.0"
    }

}
