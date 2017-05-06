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

open class VideoPlayerViewController: NSViewController {

    open let player: AVPlayer
    
    open var detached = false
    
    public init(player: AVPlayer) {
        self.player = player
        
        super.init(nibName: nil, bundle: nil)!
    }
    
    required public init?(coder: NSCoder) {
        fatalError("VideoPlayerViewController can't be initialized with a coder")
    }
    
    fileprivate lazy var playerContainer: PlayerContainerViewController = {
        let c = PlayerContainerViewController(player: self.player)
        
        c.view.frame = self.view.bounds
        
        return c
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
        
        addChildViewController(playerContainer)
        
        playerContainer.view.autoresizingMask = [.viewWidthSizable, .viewHeightSizable]
        playerContainer.view.frame = view.bounds
        view.addSubview(playerContainer.view)
        
        view.addSubview(progressIndicator)
        view.addConstraints([
            NSLayoutConstraint(item: progressIndicator, attribute: .centerX, relatedBy: .equal, toItem: view, attribute: .centerX, multiplier: 1.0, constant: 0.0),
            NSLayoutConstraint(item: progressIndicator, attribute: .centerY, relatedBy: .equal, toItem: view, attribute: .centerY, multiplier: 1.0, constant: 0.0),
        ])
        
        progressIndicator.layer?.zPosition = 999
    }
    
    override open func viewDidLoad() {
        super.viewDidLoad()
        
        playerContainer.playerView.delegate = self
        
        player.addObserver(self, forKeyPath: #keyPath(AVPlayer.status), options: [.initial, .new], context: nil)
        player.addObserver(self, forKeyPath: #keyPath(AVPlayer.currentItem.presentationSize), options: [.initial, .new], context: nil)
        
        progressIndicator.startAnimation(nil)
    }
    
    // MARK: - Player Observation
    
    open override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
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
        
        player.removeObserver(self, forKeyPath: #keyPath(AVPlayer.currentItem.presentationSize))
        player.removeObserver(self, forKeyPath: #keyPath(AVPlayer.status))
    }
    
}

extension VideoPlayerViewController: PUIPlayerViewDelegate {
    
    public func playerViewDidSelectTogglePiP(_ playerView: PUIPlayerView) {
        // TODO: PiP will have to be implemented directly instead of using PIPContainer
        let alert = NSAlert()
        alert.messageText = "Not Implemented"
        alert.informativeText = "PiP is not implemented yet"
        alert.runModal()
    }
    
    public func playerViewDidSelectToggleFullScreen(_ playerView: PUIPlayerView) {
        if let playerWindow = playerView.window as? PUIPlayerWindow {
            playerWindow.toggleFullScreen(self)
        } else {
            detach(forEnteringFullscreen: true)
        }
    }
    
    public func playerViewDidSelectAddAnnotation(_ playerView: PUIPlayerView, from view: NSView?) {
        
    }
    
}
