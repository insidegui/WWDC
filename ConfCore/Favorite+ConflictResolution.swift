//
//  Favorite+ConflictResolution.swift
//  ConfCore
//
//  Created by Guilherme Rambo on 25/05/18.
//  Copyright © 2018 Guilherme Rambo. All rights reserved.
//

import Foundation
import CloudKit
import os.log

extension Favorite {

    public static func resolveConflict(clientRecord: CKRecord, serverRecord: CKRecord) -> CKRecord? {
        // Client record always wins, take server record and update isDeleted (only property that matters for favorites)
        serverRecord["isDeleted"] = clientRecord["isDeleted"]

        return serverRecord
    }

}
