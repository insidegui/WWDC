//
//  WatchWWDCActivity.swift
//  WWDC
//
//  Created by Guilherme Rambo on 11/06/21.
//  Copyright © 2021 Guilherme Rambo. All rights reserved.
//

import Foundation
import GroupActivities
import ConfCore

@available(macOS 12.0, *)
struct WatchWWDCActivity: GroupActivity {
    
    let sessionID: String
    var metadata: GroupActivityMetadata

    init(with session: Session) {
        var meta = GroupActivityMetadata()
        
        meta.title = "Watch WWDC session \"\(session.title)\""

        if let imageURLStr = session.asset(ofType: .image)?.remoteURL,
           let imageURL = URL(string: imageURLStr),
           let image = ImageDownloadCenter.shared.cachedThumbnail(from: imageURL) {
            meta.previewImage = image.cgImage
        }
        
        self.sessionID = session.identifier
        self.metadata = meta
    }

}
