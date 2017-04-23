//
//  VideoPlayerViewController.swift
//  WWDCPlayer
//
//  Created by Guilherme Rambo on 04/06/16.
//  Copyright © 2016 Guilherme Rambo. All rights reserved.
//

import Cocoa
import AVFoundation
import AVKit

public struct VideoPlayerViewControllerMetadata {
    public let title: String?
    public let subtitle: String?
    public let description: String?
    public let imageURL: URL?
    
    public init(title: String?, subtitle: String?, description: String?, imageURL: URL?) {
        self.title = title
        self.subtitle = subtitle
        self.description = description
        self.imageURL = imageURL
    }
}

open class VideoPlayerViewController: NSViewController {

    open let metadata: VideoPlayerViewControllerMetadata
    open let player: AVPlayer
    
    open var detached = false
    
    public init(player: AVPlayer, metadata: VideoPlayerViewControllerMetadata) {
        self.metadata = metadata
        self.player = player
        
        super.init(nibName: nil, bundle: nil)!
    }
    
    required public init?(coder: NSCoder) {
        fatalError("VideoPlayerViewController can't be initialized with a coder")
    }
    
    fileprivate lazy var playerView: AVPlayerView = {
        let p = AVPlayerView(frame: NSZeroRect)
        
        p.translatesAutoresizingMaskIntoConstraints = false
        p.controlsStyle = .floating
        
        return p
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
    
    open override func loadView() {
        view = NSView(frame: NSZeroRect)
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.black.cgColor
        
        view.addSubview(playerView)
        view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "|-(0)-[playerView]-(0)-|", options: [], metrics: nil, views: ["playerView": playerView]))
        view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|-(0)-[playerView]-(0)-|", options: [], metrics: nil, views: ["playerView": playerView]))
        
        view.addSubview(progressIndicator)
        view.addConstraints([
            NSLayoutConstraint(item: progressIndicator, attribute: .centerX, relatedBy: .equal, toItem: view, attribute: .centerX, multiplier: 1.0, constant: 0.0),
            NSLayoutConstraint(item: progressIndicator, attribute: .centerY, relatedBy: .equal, toItem: view, attribute: .centerY, multiplier: 1.0, constant: 0.0),
        ])
        
        progressIndicator.layer?.zPosition = 999
    }
    
    override open func viewDidLoad() {
        super.viewDidLoad()
        
        registerPlayerObservationForKeyPath("status") { [weak self] in
            guard let weakSelf = self else { return }
            
            switch weakSelf.player.status {
            case .readyToPlay, .failed:
                weakSelf.progressIndicator.stopAnimation(nil)
                weakSelf.progressIndicator.isHidden = true
            default: break
            }
        }
        
        registerPlayerObservationForKeyPath("currentItem.presentationSize") { [weak self] in
            guard let weakSelf = self else { return }
            
            guard let size = weakSelf.player.currentItem?.presentationSize, size != NSZeroSize else { return }
            
            (weakSelf.view.window as? VideoPlayerWindow)?.aspectRatio = size
        }
        
        progressIndicator.startAnimation(nil)
        
        title = metadata.title
        playerView.player = player
        
        let doubleClickGesture = NSClickGestureRecognizer(target: self, action: #selector(doubleClickedPlayerView))
        doubleClickGesture.numberOfClicksRequired = 2
        playerView.addGestureRecognizer(doubleClickGesture)
        
        player.play()
    }
    
    @objc fileprivate func doubleClickedPlayerView() {
        if let playerWindow = view.window as? VideoPlayerWindow {
            playerWindow.toggleFullScreen(self)
        } else {
            detach(forEnteringFullscreen: true)
        }
    }
    
    // MARK: - Player Observation
    
    fileprivate var playerObservations = Dictionary<String, () -> Void>()
    
    fileprivate func registerPlayerObservationForKeyPath(_ keyPath: String, callback: @escaping () -> ()) {
        playerObservations[keyPath] = callback
        player.addObserver(self, forKeyPath: keyPath, options: [.initial, .new], context: nil)
    }
    
    open override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        guard let keyPath = keyPath else { return }
        
        if let callback = playerObservations[keyPath] {
            DispatchQueue.main.async(execute: callback)
        } else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }
    
    // MARK: - Detach
    
    fileprivate var detachedWindowController: VideoPlayerWindowController!
    
    open func detach(forEnteringFullscreen fullscreen: Bool = false) {
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
        
        playerObservations.forEach({ self.player.removeObserver(self, forKeyPath: $0.0) })
    }
    
}
