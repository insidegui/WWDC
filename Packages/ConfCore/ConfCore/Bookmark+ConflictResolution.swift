//
//  Bookmark+ConflictResolution.swift
//  ConfCore
//
//  Created by Guilherme Rambo on 25/05/18.
//  Copyright © 2018 Guilherme Rambo. All rights reserved.
//

import Foundation
import CloudKit
import os.log

extension Bookmark {

    public static func resolveConflict(clientRecord: CKRecord, serverRecord: CKRecord) -> CKRecord? {
        // Client record always wins
        serverRecord["isDeleted"] = clientRecord["isDeleted"]
        serverRecord["body"] = clientRecord["body"]
        serverRecord["attributedBody"] = clientRecord["attributedBody"]

        return serverRecord
    }

}
