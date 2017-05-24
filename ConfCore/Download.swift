//
//  Download.swift
//  WWDC
//
//  Created by Guilherme Rambo on 06/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
import RealmSwift

@available(*, deprecated: 1.0.0, message: "Provided for legacy support only, do not use this!")
enum DownloadStatus: String {
    case none
    case downloading
    case paused
    case failed
    case completed
}

@available(*, deprecated: 1.0.0, message: "Provided for legacy support only, do not use this!")
public class Download: Object {
    
    /// Unique identifier
    public dynamic var identifier = UUID().uuidString
    
    /// The session this download is associated with
    public dynamic var sessionIdentifier = ""
    
    /// When the download was started
    public dynamic var createdAt = Date()
    
    /// The current progress of the download (from 0 to 1)
    public dynamic var progress: Double = 0.0
    
    /// The raw status of the download
    internal dynamic var rawStatus: String = DownloadStatus.none.rawValue
    
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
