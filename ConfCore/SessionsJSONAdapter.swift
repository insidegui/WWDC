//
//  SessionsJSONAdapter.swift
//  WWDC
//
//  Created by Guilherme Rambo on 15/02/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Foundation
import SwiftyJSON

enum AssetKeys: String, JSONSubscriptType {
    case id, year, title, downloadHD, downloadSD, slides, hls, images, shelf, duration

    var jsonKey: JSONKey {
        return JSONKey.key(rawValue)
    }
}

private enum SessionKeys: String, JSONSubscriptType {
    case id, year, title, platforms, description, startTime, eventContentId, eventId, media, webPermalink, staticContentId

    case track = "trackId"

    var jsonKey: JSONKey {
        return JSONKey.key(rawValue)
    }
}

final class SessionsJSONAdapter: Adapter {

    typealias InputType = JSON
    typealias OutputType = Session

    func adapt(_ input: JSON) -> Result<Session, AdapterError> {
        guard let id = input[SessionKeys.id].string else {
            return .error(.missingKey(SessionKeys.id))
        }

        guard let eventIdentifier = input[SessionKeys.eventId].string else {
            return .error(.missingKey(SessionKeys.eventId))
        }

        let eventYear = eventIdentifier.replacingOccurrences(of: "wwdc", with: "")

        guard let title = input[SessionKeys.title].string else {
            return .error(.missingKey(SessionKeys.title))
        }

        guard let summary = input[SessionKeys.description].string else {
            return .error(.missingKey(SessionKeys.description))
        }

        guard let trackIdentifier = input[SessionKeys.track].int else {
            return .error(.missingKey(SessionKeys.track))
        }

        guard let eventContentId = input[SessionKeys.eventContentId].int else {
            return .error(.missingKey(SessionKeys.eventContentId))
        }

        let session = Session()

        if let focusesJson = input[SessionKeys.platforms].array {
            if case .success(let focuses) = FocusesJSONAdapter().adapt(focusesJson) {
                session.focuses.append(objectsIn: focuses)
            }
        }

        if let url = input[SessionKeys.media][AssetKeys.hls].string {
            let streaming = SessionAsset()

            streaming.rawAssetType = SessionAssetType.streamingVideo.rawValue
            streaming.remoteURL = url
            streaming.year = Int(eventYear) ?? -1
            streaming.sessionId = id

            session.assets.append(streaming)
        }

        if let hd = input[SessionKeys.media][AssetKeys.downloadHD].string {
            let hdVideo = SessionAsset()
            hdVideo.rawAssetType = SessionAssetType.hdVideo.rawValue
            hdVideo.remoteURL = hd
            hdVideo.year = Int(eventYear) ?? -1
            hdVideo.sessionId = id

            let filename = URL(string: hd)?.lastPathComponent ?? "\(title).mp4"
            hdVideo.relativeLocalURL = "\(eventYear)/\(filename)"

            session.assets.append(hdVideo)
        }

        if let sd = input[SessionKeys.media][AssetKeys.downloadSD].string {
            let sdVideo = SessionAsset()
            sdVideo.rawAssetType = SessionAssetType.sdVideo.rawValue
            sdVideo.remoteURL = sd
            sdVideo.year = Int(eventYear) ?? -1
            sdVideo.sessionId = id

            let filename = URL(string: sd)?.lastPathComponent ?? "\(title).mp4"
            sdVideo.relativeLocalURL = "\(eventYear)/\(filename)"

            session.assets.append(sdVideo)
        }

        if let slides = input[SessionKeys.media][AssetKeys.slides].string {
            let slidesAsset = SessionAsset()
            slidesAsset.rawAssetType = SessionAssetType.slides.rawValue
            slidesAsset.remoteURL = slides
            slidesAsset.year = Int(eventYear) ?? -1
            slidesAsset.sessionId = id

            session.assets.append(slidesAsset)
        }

        if let permalink = input[SessionKeys.webPermalink].string {
            let webPageAsset = SessionAsset()
            webPageAsset.rawAssetType = SessionAssetType.webpage.rawValue
            webPageAsset.remoteURL = permalink
            webPageAsset.year = Int(eventYear) ?? -1
            webPageAsset.sessionId = id

            session.assets.append(webPageAsset)
        }

        session.staticContentId = "\(input[SessionKeys.staticContentId].intValue)"
        session.identifier = id
        session.number = "\(eventContentId)"
        session.title = title
        session.summary = summary
        session.trackIdentifier = "\(trackIdentifier)"
        session.mediaDuration = input[SessionKeys.media][AssetKeys.duration].doubleValue

        session.eventIdentifier = eventIdentifier

        return .success(session)
    }

}
