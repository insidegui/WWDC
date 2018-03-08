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

    public static func == (lhs: CMSUserProfile, rhs: CMSUserProfile) -> Bool {
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
        if let avatarAsset = record[.avatar] as? CKAsset {
            avatarFileURL = avatarAsset.fileURL
            avatar = NSImage(contentsOf: avatarAsset.fileURL)
        }

        let adminFlag = (record[.isAdmin] as? Int == 1)

        originatingRecord = record
        identifier = record.recordID.recordName
        name = record[.name] as? String ?? ""
        isAdmin = adminFlag
    }

    public func makeRecord() throws -> CKRecord {
        guard let record = originatingRecord else {
            throw CMSCloudKitError.invalidData("User record must have a preexisting record")
        }

        record[.name] = name
        record[.isAdmin] = isAdmin ? 1 : 0

        if let avatarUrl = avatarFileURL, avatarUrl.isFileURL {
            record[.avatar] = CKAsset(fileURL: avatarUrl)
        } else {
            record[.avatar] = nil
        }

        return record
    }

}
