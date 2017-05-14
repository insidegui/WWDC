//
//  PUIPictureContainerViewController.swift
//  PlayerUI
//
//  Created by Guilherme Rambo on 13/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
import AVFoundation

final class PUIPictureContainerViewController: NSViewController {
    
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
        
        playerLayer.frame = view.bounds
        playerLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        
        view.layer?.addSublayer(playerLayer)
    }
    
}
