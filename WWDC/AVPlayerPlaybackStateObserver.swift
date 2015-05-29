//
//  AVPlayerPlaybackStateObserver.swift
//  WWDC
//
//  Created by Denis Stanishevsky on 27/05/15.
//  Copyright (c) 2015 Guilherme Rambo. All rights reserved.
//

import Cocoa
import AVFoundation

@objc class AVPlayerPlaybackStateObserver {
    typealias Observer = (Bool) -> Void
    
    var player: AVPlayer?
    var observer: Observer?
    let period: NSTimeInterval
    var timer: NSTimer?
    var isPlaying: Bool?
    
    init(player: AVPlayer, period: NSTimeInterval, observer: Observer) {
        self.player = player
        self.observer = observer
        self.period = period
    }
    
    func startObserving() {
        if timer == nil {
            checkPlayingState()
        }
    }
    
    func stopObserving() {
        if timer != nil {
            timer!.invalidate()
            timer = nil
            isPlaying = nil
        }
    }
    
    func disposeObserver() {
        stopObserving()
        player = nil
        observer = nil
    }
    
    func checkPlayingState() {
        if player == nil || observer == nil {
            stopObserving()
            return;
        }
        
        // check if state changed
        let isPlaying = player!.rate != 0
        if self.isPlaying == nil || self.isPlaying! != isPlaying {
            self.isPlaying = isPlaying
            observer!(isPlaying)
        }
        
        // use polling only during playback, invalidate if stopped
        if !isPlaying && timer != nil {
            stopObserving()
        }
        else if isPlaying && timer == nil {
            timer = NSTimer.scheduledTimerWithTimeInterval(period, target: self, selector: Selector("checkPlayingState"), userInfo: nil, repeats: true)
        }
    }
    
}
