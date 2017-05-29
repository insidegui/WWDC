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

protocol VideoPlayerViewControllerDelegate: class {
    
    func createBookmark(at timecode: Double, with snapshot: NSImage?)
    
}

final class VideoPlayerViewController: NSViewController {

    private var disposeBag = DisposeBag()
    
    weak var delegate: VideoPlayerViewControllerDelegate?
    
    var sessionViewModel: SessionViewModel {
        didSet {
            self.disposeBag = DisposeBag()
            
            updateUI()
        }
    }
    
    weak var player: AVPlayer! {
        didSet {
            reset(oldValue: oldValue)
        }
    }
    
    var detached = false
    
    var playerWillExitPictureInPicture: (() -> Void)?
    
    init(player: AVPlayer, session: SessionViewModel) {
        self.sessionViewModel = session
        self.player = player
        
        super.init(nibName: nil, bundle: nil)!
    }
    
    required public init?(coder: NSCoder) {
        fatalError("VideoPlayerViewController can't be initialized with a coder")
    }
    
    lazy var playerView: PUIPlayerView = {
        return PUIPlayerView(player: self.player)
    }()
    
    fileprivate lazy var progressIndicator: NSProgressIndicator = {
        let p = NSProgressIndicator(frame: NSZeroRect)
        
        p.controlSize = .regular
        p.style = .spinningStyle
        p.isIndeterminate = true
        p.translatesAutoresizingMaskIntoConstraints = false
        
        if #available(OSX 10.11, *) {
            p.appearance = NSAppearance(appearanceNamed: "WhiteSpinner", bundle: Bundle(for: VideoPlayerViewController.self))
        }
        
        p.sizeToFit()
        
        return p
    }()
    
    override func loadView() {
        view = NSView(frame: NSZeroRect)
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.black.cgColor
        
        playerView.translatesAutoresizingMaskIntoConstraints = false
        playerView.frame = view.bounds
        view.addSubview(playerView)
        
        playerView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        playerView.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        playerView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        playerView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        
        view.addSubview(progressIndicator)
        view.addConstraints([
            NSLayoutConstraint(item: progressIndicator, attribute: .centerX, relatedBy: .equal, toItem: view, attribute: .centerX, multiplier: 1.0, constant: 0.0),
            NSLayoutConstraint(item: progressIndicator, attribute: .centerY, relatedBy: .equal, toItem: view, attribute: .centerY, multiplier: 1.0, constant: 0.0),
        ])
        
        progressIndicator.layer?.zPosition = 999
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        playerView.delegate = self
        
        reset(oldValue: nil)
        updateUI()
        
        NotificationCenter.default.addObserver(self, selector: #selector(annotationSelected(notification:)), name: .TranscriptControllerDidSelectAnnotation, object: nil)
    }
    
    func reset(oldValue: AVPlayer?) {
        if let oldPlayer = oldValue {
            playerView.player = nil
            
            oldPlayer.pause()
            oldPlayer.cancelPendingPrerolls()
            oldPlayer.removeObserver(self, forKeyPath: #keyPath(AVPlayer.status))
            oldPlayer.removeObserver(self, forKeyPath: #keyPath(AVPlayer.currentItem.presentationSize))
        }
        
        player.addObserver(self, forKeyPath: #keyPath(AVPlayer.status), options: [.initial, .new], context: nil)
        player.addObserver(self, forKeyPath: #keyPath(AVPlayer.currentItem.presentationSize), options: [.initial, .new], context: nil)
        
        player.play()
        
        progressIndicator.startAnimation(nil)
        
        playerView.player = player
    }
    
    func updateUI() {
        let bookmarks = sessionViewModel.session.bookmarks.sorted(byKeyPath: "timecode")
        Observable.collection(from: bookmarks).observeOn(MainScheduler.instance).subscribe(onNext: { [weak self] bookmarks in
            self?.playerView.annotations = bookmarks.toArray()
        }).addDisposableTo(self.disposeBag)
    }
    
    @objc private func annotationSelected(notification: Notification) {
        guard let (transcript, annotation) = notification.object as? (Transcript, TranscriptAnnotation) else { return }
        guard transcript.identifier == sessionViewModel.session.transcriptIdentifier else { return }
        
        let time = CMTimeMakeWithSeconds(annotation.timecode, 90000)
        player.seek(to: time)
    }
    
    // MARK: - Player Observation
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        guard let keyPath = keyPath else { return }
        
        if keyPath == #keyPath(AVPlayer.currentItem.presentationSize) {
            DispatchQueue.main.async(execute: playerItemPresentationSizeDidChange)
        } else if keyPath == #keyPath(AVPlayer.status) {
            DispatchQueue.main.async(execute: playerStatusDidChange)
        } else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }
    
    private func playerItemPresentationSizeDidChange() {
        guard let size = player.currentItem?.presentationSize, size != NSZeroSize else { return }
        
        (view.window as? PUIPlayerWindow)?.aspectRatio = size
    }
    
    private func playerStatusDidChange() {
        switch player.status {
        case .readyToPlay, .failed:
            progressIndicator.stopAnimation(nil)
            progressIndicator.isHidden = true
        default: break
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
        
        detachedWindowController.showWindow(self)
        
        detached = true
    }
    
    deinit {
        #if DEBUG
            Swift.print("VideoPlayerViewController is gone")
        #endif
        
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
            self.delegate?.createBookmark(at: timestamp, with: snapshot)
        }
    }
    
    private func snapshotPlayer(completion: @escaping (NSImage?) -> Void) {
        playerView.snapshotPlayer(completion: completion)
    }
    
    func playerViewWillExitPictureInPictureMode(_ playerView: PUIPlayerView) {
        self.playerWillExitPictureInPicture?()
    }
    
    func playerViewWillEnterPictureInPictureMode(_ playerView: PUIPlayerView) {
        
    }
    
}
