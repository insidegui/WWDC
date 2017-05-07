//
//  LiveVideosAdapter.swift
//  WWDC
//
//  Created by Guilherme Rambo on 15/02/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Foundation
import SwiftyJSON

private enum LiveVideoKeys: String, JSONSubscriptType {
    case sessionId, tvosUrl
    
    var jsonKey: JSONKey {
        return JSONKey.key(rawValue)
    }
}

final class LiveVideosAdapter: Adapter {
    
    typealias InputType = JSON
    typealias OutputType = SessionAsset
    
    func adapt(_ input: JSON) -> Result<SessionAsset, AdapterError> {
        guard let sessionId = input[LiveVideoKeys.sessionId].string else {
            return .error(.missingKey(LiveVideoKeys.sessionId))
        }
        
        guard let url = input[LiveVideoKeys.tvosUrl].string else {
            return .error(.missingKey(LiveVideoKeys.tvosUrl))
        }
        
        let asset = SessionAsset()
        // Live assets are always for the current year
        asset.year = Calendar.current.component(.year, from: Date())
        asset.sessionId = sessionId
        asset.rawAssetType = SessionAssetType.liveStreamVideo.rawValue
        asset.remoteURL = url
        
        return .success(asset)
    }
    
}
