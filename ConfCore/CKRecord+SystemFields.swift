//
//  CKRecord+SystemFields.swift
//  ConfCore
//
//  Created by Guilherme Rambo on 24/05/18.
//  Copyright © 2018 Guilherme Rambo. All rights reserved.
//

import Foundation
import CloudKit

extension CKRecord {

    var encodedSystemFields: Data {
        let data = NSMutableData()
        let coder = NSKeyedArchiver(forWritingWith: data)
        coder.requiresSecureCoding = true
        encodeSystemFields(with: coder)
        coder.finishEncoding()

        return data as Data
    }

}
