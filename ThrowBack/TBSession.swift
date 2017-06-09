//
//  TBSession.swift
//  WWDC
//
//  Created by Guilherme Rambo on 13/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Foundation
import RealmSwift

internal struct TBSession {

    let identifier: String
    let isFavorite: Bool
    let isDownloaded: Bool
    let position: Double
    let relativePosition: Double

    init?(_ migrationObject: MigrationObject?) {
        guard let obj = migrationObject else { return nil }

        guard var identifier = obj["uniqueId"] as? String else {
            return nil
        }

        identifier = identifier.replacingOccurrences(of: "#", with: "")

        guard let isFavorite = obj["favorite"] as? Bool else { return nil }
        guard let isDownloaded = obj["downloaded"] as? Bool else { return nil }
        guard let position = obj["currentPosition"] as? Double else { return nil }
        guard let relativePosition = obj["progress"] as? Double else { return nil }

        self.identifier = identifier
        self.isFavorite = isFavorite
        self.position = position
        self.relativePosition = relativePosition
        self.isDownloaded = isDownloaded
    }

}
