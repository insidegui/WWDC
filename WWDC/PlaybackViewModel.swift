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
        return assets.filter({ $0.assetType == type.rawValue }).first
    }
    
}

struct PlaybackViewModel {
    
    let sessionViewModel: SessionViewModel
    let player: AVPlayer
    
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
    }
    
}
