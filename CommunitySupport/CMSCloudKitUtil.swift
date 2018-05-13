//
//  CMSCloudKitUtil.swift
//  WWDC
//
//  Created by Guilherme Rambo on 15/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Foundation
import CloudKit
import os.log

/// Helper method to retry a CloudKit operation when its error suggests it
///
/// - Parameters:
///   - error: The error returned from a CloudKit operation
///   - block: A block to be executed after a delay if the error is recoverable
/// - Returns: If the error can't be retried, returns the error
internal func retryCloudKitOperationIfPossible(with error: Error?, block: @escaping () -> Void) -> Error? {
    guard error != nil else { return nil }

    guard let effectiveError = error as? CKError else {
        os_log("CloudKit returned an error that was not a CKError, this is nuts! The offending error was: %{public}@",
               log: .default,
               type: .fault,
               String(describing: error))

        return error
    }

    guard let retryAfter = effectiveError.retryAfterSeconds else {
        os_log("CloudKit error: %{public}@", log: .default, type: .error, String(describing: effectiveError))
        return effectiveError
    }

    os_log("Recoverable CloudKit error, will retry operation in %{public}f seconds: %{public}@",
           log: .default,
           type: .error,
           retryAfter, String(describing: effectiveError))

    DispatchQueue.main.asyncAfter(deadline: .now() + retryAfter) {
        block()
    }

    return nil
}
