//
//  SessionAsset.swift
//  WWDC
//
//  Created by Guilherme Rambo on 06/02/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
import RealmSwift

enum SessionAssetType: String {
    case hdVideo = "WWDCSessionAssetTypeHDVideo"
    case sdVideo = "WWDCSessionAssetTypeSDVideo"
    case image = "WWDCSessionAssetTypeShelfImage"
    case slides = "WWDCSessionAssetTypeSlidesPDF"
    case streamingVideo = "WWDCSessionAssetTypeStreamingVideo"
    case liveStreamVideo = "WWDCSessionAssetTypeLiveStreamVideo"
    case webpage = "WWDCSessionAssetTypeWebpageURL"
}

/// Session assets are resources associated with sessions, like videos, PDFs and useful links
class SessionAsset: Object {
    
    /// The type of asset:
    ///
    /// - WWDCSessionAssetTypeHDVideo
    /// - WWDCSessionAssetTypeSDVideo
    /// - WWDCSessionAssetTypeShelfImage
    /// - WWDCSessionAssetTypeSlidesPDF
    /// - WWDCSessionAssetTypeStreamingVideo
    /// - WWDCSessionAssetTypeWebpageURL
    dynamic var assetType = ""
    
    /// The year of the session this asset belongs to
    dynamic var year = 0
    
    /// The id of the session this asset belongs to
    dynamic var sessionId = ""
    
    /// URL for this asset
    dynamic var remoteURL = ""
    
    /// Relative local URL to save the asset to when downloading
    dynamic var relativeLocalURL = ""
    
    /// Whether this asset has been download or not
    dynamic var isDownloaded = false
    
    /// The session this asset belongs to
    let session = LinkingObjects(fromType: Session.self, property: "assets")
    
    override class func primaryKey() -> String? {
        return "remoteURL"
    }
    
}
