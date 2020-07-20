//
//  Error+CloudKit.swift
//  ConfCore
//
//  Created by Guilherme Rambo on 25/05/18.
//  Copyright © 2018 Guilherme Rambo. All rights reserved.
//

import Foundation
import CloudKit
import os.log

extension Error {

    var isCloudKitConflict: Bool {
        guard let effectiveError = self as? CKError else { return false }

        return effectiveError.code == .serverRecordChanged
    }

    func resolveConflict(with resolver: (CKRecord, CKRecord) -> CKRecord?) -> CKRecord? {
        guard let effectiveError = self as? CKError else {
            os_log("resolveConflict called on an error that was not a CKError. The error was %{public}@",
                   log: .default,
                   type: .fault,
                   String(describing: self))
            return nil
        }

        guard effectiveError.code == .serverRecordChanged else {
            os_log("resolveConflict called on a CKError that was not a serverRecordChanged error. The error was %{public}@",
                   log: .default,
                   type: .fault,
                   String(describing: effectiveError))
            return nil
        }

        guard let clientRecord = effectiveError.userInfo[CKRecordChangedErrorClientRecordKey] as? CKRecord else {
            os_log("Failed to obtain client record from serverRecordChanged error. The error was %{public}@",
                   log: .default,
                   type: .fault,
                   String(describing: effectiveError))
            return nil
        }

        guard let serverRecord = effectiveError.userInfo[CKRecordChangedErrorServerRecordKey] as? CKRecord else {
            os_log("Failed to obtain server record from serverRecordChanged error. The error was %{public}@",
                   log: .default,
                   type: .fault,
                   String(describing: effectiveError))
            return nil
        }

        return resolver(clientRecord, serverRecord)
    }

    @discardableResult func retryCloudKitOperationIfPossible(_ log: OSLog? = nil, in queue: DispatchQueue = .main, with block: @escaping () -> Void) -> Bool {
        let effectiveLog = log ?? .default

        guard let effectiveError = self as? CKError else { return false }

        guard let retryDelay = effectiveError.retryAfterSeconds else {
            os_log("Error is not recoverable", log: effectiveLog, type: .error)
            return false
        }

        os_log("Error is recoverable. Will retry after %{public}f seconds", log: effectiveLog, type: .error, retryDelay)

        queue.asyncAfter(deadline: .now() + retryDelay) {
            block()
        }

        return true
    }

}
