//
//  Download.swift
//  WWDC
//
//  Created by Guilherme Rambo on 06/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
import RealmSwift

@available(*, deprecated, message: "Provided for legacy support only, do not use this!")
enum DownloadStatus: String {
    case none
    case downloading
    case paused
    case failed
    case completed
}

@available(*, deprecated, message: "Provided for legacy support only, do not use this!")
public class Download: Object {

    /// Unique identifier
    @objc public dynamic var identifier = UUID().uuidString

    /// The session this download is associated with
    @objc public dynamic var sessionIdentifier = ""

    /// When the download was started
    @objc public dynamic var createdAt = Date()

    /// The current progress of the download (from 0 to 1)
    @objc public dynamic var progress: Double = 0.0

    /// The raw status of the download
    @objc internal dynamic var rawStatus: String = DownloadStatus.none.rawValue

    /// The status of the download
    var status: DownloadStatus {
        get {
            return DownloadStatus(rawValue: rawStatus) ?? .none
        }
        set {
            rawStatus = newValue.rawValue
        }
    }

    public override class func primaryKey() -> String? {
        return "identifier"
    }

}
