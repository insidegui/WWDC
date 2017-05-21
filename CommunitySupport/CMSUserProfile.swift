//
//  CMSUserProfile.swift
//  WWDC
//
//  Created by Guilherme Rambo on 15/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
import CloudKit

public struct CMSUserProfile {
    
    public static let recordType = "Users"
    
    public var originatingRecord: CKRecord?
    public var avatarFileURL: URL?
    
    public let identifier: String
    public var name: String
    public var avatar: NSImage?
    public let isAdmin: Bool
    
    public static var empty: CMSUserProfile {
        return CMSUserProfile(originatingRecord: nil,
                              avatarFileURL: nil,
                              identifier: "",
                              name: "",
                              avatar: nil,
                              isAdmin: false)
    }
    
}

extension CMSUserProfile: Equatable {
    
    var isEmpty: Bool {
        return identifier.isEmpty
    }
    
    public static func ==(lhs: CMSUserProfile, rhs: CMSUserProfile) -> Bool {
        return lhs.identifier == rhs.identifier
            && lhs.avatarFileURL == rhs.avatarFileURL
            && lhs.name == rhs.name
            && lhs.isAdmin == rhs.isAdmin
    }
    
}

enum CMSUserProfileKey: String {
    case name
    case isAdmin
    case avatar
}

extension CKRecord {
    
    subscript(key: CMSUserProfileKey) -> Any? {
        get {
            return self[key.rawValue]
        }
        set {
            self[key.rawValue] = newValue as? CKRecordValue
        }
    }
    
}

extension CMSUserProfile: CMSCloudKitRepresentable {
    
    public init(record: CKRecord) throws {
        let name = record[.name] as? String ?? ""
        
        guard let avatar = record[.avatar] as? CKAsset else {
            throw CMSCloudKitError.missingKey(CMSUserProfileKey.avatar.rawValue)
        }
        
        guard let isAdmin = record[.isAdmin] as? Int else {
            throw CMSCloudKitError.missingKey(CMSUserProfileKey.isAdmin.rawValue)
        }
        
        self.originatingRecord = record
        self.identifier = record.recordID.recordName
        self.name = name
        self.isAdmin = (isAdmin == 1)
        self.avatarFileURL = avatar.fileURL
        self.avatar = NSImage(contentsOf: avatar.fileURL)
    }
    
    public func makeRecord() throws -> CKRecord {
        guard let record = self.originatingRecord else {
            throw CMSCloudKitError.invalidData("User record must have a preexisting record")
        }
        
        record[.name] = name
        record[.isAdmin] = isAdmin ? 1 : 0
        
        if let avatarUrl = self.avatarFileURL, avatarUrl.isFileURL {
            record[.avatar] = CKAsset(fileURL: avatarUrl)
        } else {
            record[.avatar] = nil
        }
        
        return record
    }
    
}
