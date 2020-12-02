//
//  SessionProgress+ConflictResolution.swift
//  ConfCore
//
//  Created by Guilherme Rambo on 26/05/18.
//  Copyright © 2018 Guilherme Rambo. All rights reserved.
//

import Foundation
import CloudKit
import os.log

extension SessionProgress {

    public static func resolveConflict(clientRecord: CKRecord, serverRecord: CKRecord) -> CKRecord? {
        // Client record always wins
        serverRecord["currentPosition"] = clientRecord["currentPosition"]
        serverRecord["relativePosition"] = clientRecord["relativePosition"]
        serverRecord["updatedAt"] = clientRecord["updatedAt"]

        return serverRecord
    }

}
