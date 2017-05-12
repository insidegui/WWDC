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
            return "Invalid stream url: \(url)"
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
    
    private var timeObserver: Any?
    
    init(sessionViewModel: SessionViewModel, storage: Storage) throws {
        self.sessionViewModel = sessionViewModel
        
        guard let session = storage.session(with: sessionViewModel.identifier) else {
            throw PlaybackError.sessionNotFound(sessionViewModel.identifier)
        }
        
        guard let asset = session.asset(of: .streamingVideo) else {
            throw PlaybackError.assetNotFound(session.identifier)
        }
        
        // TODO: play local video file when downloaded
        
        guard let streamUrl = URL(string: asset.remoteURL) else {
            throw PlaybackError.invalidAsset(asset.remoteURL)
        }
        
        self.player = AVPlayer(url: streamUrl)
        
        let p = session.currentPosition()
        self.player.seek(to: CMTimeMakeWithSeconds(Float64(p), 9000))
        
        self.timeObserver = self.player.addPeriodicTimeObserver(forInterval: CMTimeMakeWithSeconds(5, 9000), queue: DispatchQueue.main) { [weak self] currentTime in
            let s = Double(CMTimeGetSeconds(currentTime))
            
            self?.sessionViewModel.session.setCurrentPosition(s)
        }
    }
    
    deinit {
        if let timeObserver = timeObserver {
            player.removeTimeObserver(timeObserver)
        }
    }
    
}
