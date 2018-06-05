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
    case sessionId, tvosUrl, iosUrl, actualEndDate

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

        guard let url = input[LiveVideoKeys.tvosUrl].string ?? input[LiveVideoKeys.iosUrl].string else {
            return .error(.missingKey(LiveVideoKeys.tvosUrl))
        }

        let asset = SessionAsset()
        // Live assets are always for the current year
        asset.year = Calendar.current.component(.year, from: Date())

        // There are two assumptions being made here
        // 1 - Live assets are always for the current year
        // 2 - Live assets are always for "WWDC" events
        // FIXME: done in a rush to fix live streaming in 2018
        asset.sessionId = "wwdc\(asset.year)-"+sessionId
        asset.rawAssetType = SessionAssetType.liveStreamVideo.rawValue
        asset.remoteURL = url

        if let rawEndDate = input[LiveVideoKeys.actualEndDate].string,
            case .success(let actualEndDate) = DateTimeAdapter().adapt(rawEndDate) {
            asset.actualEndDate = actualEndDate
        }

        return .success(asset)
    }
}
