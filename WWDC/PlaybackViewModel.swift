//
//  PlaybackViewModel.swift
//  WWDC
//
//  Created by Guilherme Rambo on 23/04/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Foundation
import ConfCore
import AVFoundation
import PlayerUI

enum PlaybackError: Error {
    case sessionNotFound(String)
    case assetNotFound(String)
    case invalidAsset(String)
    
    var localizedDescription: String {
        switch self {
        case .sessionNotFound(let identifier):
            return "Unable to find session with identifier \(identifier)"
        case .assetNotFound(let identifier):
            return "Unable to find asset for session \(identifier)"
        case .invalidAsset(let url):
            return "Invalid stream: \(url)"
        }
    }
}

extension Session {
    
    func asset(of type: SessionAssetType) -> SessionAsset? {
        return assets.filter({ $0.assetType == type }).first
    }
    
}

final class PlaybackViewModel {
    
    let sessionViewModel: SessionViewModel
    let player: AVPlayer
    let isLiveStream: Bool
    
    private var timeObserver: Any?
    
    init(sessionViewModel: SessionViewModel, storage: Storage) throws {
        self.sessionViewModel = sessionViewModel
        
        guard let session = storage.session(with: sessionViewModel.identifier) else {
            throw PlaybackError.sessionNotFound(sessionViewModel.identifier)
        }
        
        var streamUrl: URL?
        
        // first, check if the session is being live streamed now
        if session.instances.filter("isCurrentlyLive == true").count > 0 {
            if let liveAsset = session.assets.filter("rawAssetType == %@", SessionAssetType.liveStreamVideo.rawValue).first, let liveURL = URL(string: liveAsset.remoteURL) {
                streamUrl = liveURL
                self.isLiveStream = true
            } else {
                self.isLiveStream = false
            }
        } else {
            self.isLiveStream = false
        }
        
        // not live
        if !self.isLiveStream {
            // must have at least streaming video asset
            guard let asset = session.asset(of: .streamingVideo) else {
                throw PlaybackError.assetNotFound(session.identifier)
            }
            
            // remote url for the streaming video must be valid
            guard let remoteUrl = URL(string: asset.remoteURL) else {
                throw PlaybackError.invalidAsset(asset.remoteURL)
            }
            
            // check if we have a downloaded file and use it instead
            if let localUrl = DownloadManager(storage).localFileURL(for: session) {
                streamUrl = localUrl
            } else {
                streamUrl = remoteUrl
            }
        }
        
        guard var finalUrl = streamUrl else {
            throw PlaybackError.invalidAsset("No valid video URL could be found")
        }
        
        #if DEBUG
        if Arguments.useTestVideo {
            finalUrl = URL(fileURLWithPath: "/Users/inside/Movies/test.m4v")
        }
        #endif
        
        self.player = AVPlayer(url: finalUrl)
        
        if !self.isLiveStream {
            let p = session.currentPosition()
            self.player.seek(to: CMTimeMakeWithSeconds(Float64(p), 9000))
            
            self.timeObserver = self.player.addPeriodicTimeObserver(forInterval: CMTimeMakeWithSeconds(5, 9000), queue: DispatchQueue.main) { [weak self] currentTime in
                guard let duration = self?.player.currentItem?.asset.duration else { return }
                guard CMTIME_IS_VALID(duration) else { return }
                
                let p = Double(CMTimeGetSeconds(currentTime))
                let d = Double(CMTimeGetSeconds(duration))
                
                self?.sessionViewModel.session.setCurrentPosition(p, d)
            }
        }
    }
    
    deinit {
        if let timeObserver = timeObserver {
            player.removeTimeObserver(timeObserver)
        }
    }
    
}
