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
    
    public static let recordType = "User"
    
    public var originatingRecord: CKRecord?
    internal var avatarFileURL: URL?
    
    public let identifier: String
    public var name: String
    public let nickname: String
    public var avatar: NSImage?
    public var site: URL?
    public let isAdmin: Bool
    
}

enum CMSUserProfileKey: String {
    case name
    case nickname
    case url
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
        guard let name = record[.name] as? String else {
            throw CMSCloudKitError.missingKey(CMSUserProfileKey.name.rawValue)
        }
        
        guard let nickname = record[.nickname] as? String else {
            throw CMSCloudKitError.missingKey(CMSUserProfileKey.nickname.rawValue)
        }
        
        guard let url = record[.url] as? String else {
            throw CMSCloudKitError.missingKey(CMSUserProfileKey.url.rawValue)
        }
        
        guard let avatar = record[.avatar] as? CKAsset else {
            throw CMSCloudKitError.missingKey(CMSUserProfileKey.avatar.rawValue)
        }
        
        guard let isAdmin = record[.isAdmin] as? Int else {
            throw CMSCloudKitError.missingKey(CMSUserProfileKey.isAdmin.rawValue)
        }
        
        self.identifier = record.recordID.recordName
        self.name = name
        self.nickname = nickname
        self.site = URL(string: url)
        self.isAdmin = (isAdmin == 1)
        self.avatarFileURL = avatar.fileURL
        self.avatar = NSImage(contentsOf: avatar.fileURL)
    }
    
    public func makeRecord() throws -> CKRecord {
        guard let recordID = self.originatingRecord?.recordID else {
            throw CMSCloudKitError.invalidData("User record must have a preexisting record ID")
        }
        
        let record = CKRecord(recordType: CMSUserProfile.recordType, recordID: recordID)
        
        record[.name] = name
        record[.nickname] = nickname
        record[.url] = site?.absoluteString
        record[.isAdmin] = isAdmin ? 1 : 0
        
        if let avatarUrl = self.avatarFileURL, avatarUrl.isFileURL {
            record[.avatar] = CKAsset(fileURL: avatarUrl)
        } else {
            record[.avatar] = nil
        }
        
        return record
    }
    
}
