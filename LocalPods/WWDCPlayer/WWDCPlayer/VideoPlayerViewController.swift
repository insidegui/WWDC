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
    public let imageURL: NSURL?
    
    public init(title: String?, subtitle: String?, description: String?, imageURL: NSURL?) {
        self.title = title
        self.subtitle = subtitle
        self.description = description
        self.imageURL = imageURL
    }
}

public class VideoPlayerViewController: NSViewController {

    public let metadata: VideoPlayerViewControllerMetadata
    public let player: AVPlayer
    
    public var detached = false
    
    public init(player: AVPlayer, metadata: VideoPlayerViewControllerMetadata) {
        self.metadata = metadata
        self.player = player
        
        super.init(nibName: nil, bundle: nil)!
    }
    
    required public init?(coder: NSCoder) {
        fatalError("VideoPlayerViewController can't be initialized with a coder")
    }
    
    private lazy var playerView: AVPlayerView = {
        let p = AVPlayerView(frame: NSZeroRect)
        
        p.translatesAutoresizingMaskIntoConstraints = false
        p.controlsStyle = .Floating
        
        return p
    }()
    
    private lazy var progressIndicator: NSProgressIndicator = {
        let p = NSProgressIndicator(frame: NSZeroRect)
        
        p.controlSize = .RegularControlSize
        p.style = .SpinningStyle
        p.indeterminate = true
        p.translatesAutoresizingMaskIntoConstraints = false
        
        if #available(OSX 10.11, *) {
            p.appearance = NSAppearance(appearanceNamed: "WhiteSpinner", bundle: NSBundle(forClass: VideoPlayerViewController.self))
        }
        
        p.sizeToFit()
        
        return p
    }()
    
    public override func loadView() {
        view = NSView(frame: NSZeroRect)
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.blackColor().CGColor
        
        view.addSubview(playerView)
        view.addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("|-(0)-[playerView]-(0)-|", options: [], metrics: nil, views: ["playerView": playerView]))
        view.addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("V:|-(0)-[playerView]-(0)-|", options: [], metrics: nil, views: ["playerView": playerView]))
        
        view.addSubview(progressIndicator)
        view.addConstraints([
            NSLayoutConstraint(item: progressIndicator, attribute: .CenterX, relatedBy: .Equal, toItem: view, attribute: .CenterX, multiplier: 1.0, constant: 0.0),
            NSLayoutConstraint(item: progressIndicator, attribute: .CenterY, relatedBy: .Equal, toItem: view, attribute: .CenterY, multiplier: 1.0, constant: 0.0),
        ])
        
        progressIndicator.layer?.zPosition = 999
    }
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        
        registerPlayerObservationForKeyPath("status") { [weak self] in
            guard let weakSelf = self else { return }
            
            switch weakSelf.player.status {
            case .ReadyToPlay, .Failed:
                weakSelf.progressIndicator.stopAnimation(nil)
                weakSelf.progressIndicator.hidden = true
            default: break
            }
        }
        
        registerPlayerObservationForKeyPath("currentItem.presentationSize") { [weak self] in
            guard let weakSelf = self else { return }
            
            guard let size = weakSelf.player.currentItem?.presentationSize where size != NSZeroSize else { return }
            
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
    
    @objc private func doubleClickedPlayerView() {
        if let playerWindow = view.window as? VideoPlayerWindow {
            playerWindow.toggleFullScreen(self)
        } else {
            detach(forEnteringFullscreen: true)
        }
    }
    
    // MARK: - Player Observation
    
    private var playerObservations = Dictionary<String, () -> Void>()
    
    private func registerPlayerObservationForKeyPath(keyPath: String, callback: () -> ()) {
        playerObservations[keyPath] = callback
        player.addObserver(self, forKeyPath: keyPath, options: [.Initial, .New], context: nil)
    }
    
    public override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
        guard let keyPath = keyPath else { return }
        
        if let callback = playerObservations[keyPath] {
            dispatch_async(dispatch_get_main_queue(), callback)
        } else {
            super.observeValueForKeyPath(keyPath, ofObject: object, change: change, context: context)
        }
    }
    
    // MARK: - Detach
    
    private var detachedWindowController: VideoPlayerWindowController!
    
    public func detach(forEnteringFullscreen fullscreen: Bool = false) {
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
