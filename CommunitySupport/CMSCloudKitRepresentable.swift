//
//  CMSCloudKitRepresentable.swift
//  WWDC
//
//  Created by Guilherme Rambo on 15/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Foundation
import CloudKit

public enum CMSCloudKitError: Error {
    case missingKey(String)
    case invalidData(String)
    case notFound
}

public protocol CMSCloudKitRepresentable {
    
    static var recordType: String { get }
    
    var originatingRecord: CKRecord? { get set }
    var identifier: String { get }
    
    init(record: CKRecord) throws
    
    func makeRecord() throws -> CKRecord
    
}
