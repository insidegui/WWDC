//
//  SessionAssetsAdapter.swift
//  WWDC
//
//  Created by Guilherme Rambo on 08/02/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Foundation
import SwiftyJSON

private enum AssetKeys: String, JSONSubscriptType {
    case id, year, title, download_hd, download_sd, slides, webpageURL, url, images, shelf
    
    var jsonKey: JSONKey {
        return JSONKey.key(rawValue)
    }
}

final class SessionAssetsJSONAdapter: Adapter {
    
    typealias InputType = JSON
    typealias OutputType = [SessionAsset]
    
    func adapt(_ input: JSON) -> Result<[SessionAsset], AdapterError> {
        guard let id = input[AssetKeys.id].string else {
            return .error(.missingKey(AssetKeys.id))
        }
        
        guard let year = input[AssetKeys.year].int else {
            return .error(.missingKey(AssetKeys.year))
        }
        
        guard let title = input[AssetKeys.title].string else {
            return .error(.missingKey(AssetKeys.title))
        }
        
        guard let url = input[AssetKeys.url].string else {
            return .error(.missingKey(AssetKeys.url))
        }
        
        var output = [SessionAsset]()
        
        let streaming = SessionAsset()
        streaming.assetType = SessionAssetType.streamingVideo.rawValue
        streaming.remoteURL = url
        
        output.append(streaming)
        
        if let hd = input[AssetKeys.download_hd].string {
            let hdVideo = SessionAsset()
            hdVideo.assetType = SessionAssetType.hdVideo.rawValue
            hdVideo.remoteURL = hd
            
            let filename = URL(string: hd)?.lastPathComponent ?? "\(title).mp4"
            hdVideo.relativeLocalURL = "\(year)/\(filename)"
            
            output.append(hdVideo)
        }
        
        if let sd = input[AssetKeys.download_sd].string {
            let sdVideo = SessionAsset()
            sdVideo.assetType = SessionAssetType.sdVideo.rawValue
            sdVideo.remoteURL = sd
            
            let filename = URL(string: sd)?.lastPathComponent ?? "\(title).mp4"
            sdVideo.relativeLocalURL = "\(year)/\(filename)"
            
            output.append(sdVideo)
        }
        
        if let slides = input[AssetKeys.slides].string {
            let slidesAsset = SessionAsset()
            slidesAsset.assetType = SessionAssetType.slides.rawValue
            slidesAsset.remoteURL = slides
            
            output.append(slidesAsset)
        }
        
        if let webpage = input[AssetKeys.webpageURL].string {
            let webpageAsset = SessionAsset()
            webpageAsset.assetType = SessionAssetType.webpage.rawValue
            webpageAsset.remoteURL = webpage
            
            output.append(webpageAsset)
        }
        
        if let image = input[AssetKeys.images][AssetKeys.shelf].string {
            let imageAsset = SessionAsset()
            imageAsset.assetType = SessionAssetType.image.rawValue
            imageAsset.remoteURL = image
            
            output.append(imageAsset)
        }
        
        return .success(output)
    }
    
}
