//
//  PlayerExtensions.swift
//  WWDC
//
//  Created by Guilherme Rambo on 04/06/16.
//  Copyright © 2016 Guilherme Rambo. All rights reserved.
//

import Cocoa
import WWDCPlayer
import AVFoundation

extension VideoPlayerViewController {
    
    class func withLiveSession(session: LiveSession) -> VideoPlayerViewController {
        let player = AVPlayer(URL: session.streamURL!)
        
        return VideoPlayerViewController(player: player, metadata: VideoPlayerViewControllerMetadata.fromLiveSession(session))
    }
    
}

extension VideoPlayerViewControllerMetadata {
    
    static func fromLiveSession(session: LiveSession) -> VideoPlayerViewControllerMetadata {
        return VideoPlayerViewControllerMetadata(title: "Live: "+session.title, subtitle: nil, description: session.summary, imageURL: nil)
    }
    
}