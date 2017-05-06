//
//  PlayerContainerViewController.swift
//  WWDC
//
//  Created by Guilherme Rambo on 06/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
import AVFoundation
import PlayerUI

final class PlayerContainerViewController: NSViewController {
    
    let player: AVPlayer
    
    var playerView: PUIPlayerView {
        return view as! PUIPlayerView
    }
    
    init(player: AVPlayer) {
        self.player = player
        
        super.init(nibName: nil, bundle: nil)!
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadView() {
        view = PUIPlayerView(player: player)
    }
    
}
