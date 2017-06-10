//
//  PUIPictureContainerViewController.swift
//  PlayerUI
//
//  Created by Guilherme Rambo on 13/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
import AVFoundation

protocol PUIPictureContainerViewControllerDelegate: class {

    func pictureContainerViewSuperviewDidChange(to superview: NSView?)

}

final class PUIPictureContainerViewController: NSViewController {

    weak var delegate: PUIPictureContainerViewControllerDelegate?

    let playerLayer: AVPlayerLayer

    init(playerLayer: AVPlayerLayer) {
        self.playerLayer = playerLayer

        super.init(nibName: nil, bundle: nil)!
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = NSView()
        view.wantsLayer = true
        view.layer = PUIBoringLayer()
        view.layer?.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        view.layer?.backgroundColor = NSColor.black.cgColor

        playerLayer.frame = view.bounds
        playerLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]

        view.layer?.addSublayer(playerLayer)

        view.addObserver(self, forKeyPath: #keyPath(NSView.superview), options: [.new], context: nil)
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == #keyPath(NSView.superview) {
            viewDidMoveToSuperview()
        } else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }

    func viewDidMoveToSuperview() {
        delegate?.pictureContainerViewSuperviewDidChange(to: view.superview)
    }

    deinit {
        view.removeObserver(self, forKeyPath: #keyPath(NSView.superview))
    }
}
