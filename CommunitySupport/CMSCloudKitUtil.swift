//
//  CMSCloudKitUtil.swift
//  WWDC
//
//  Created by Guilherme Rambo on 15/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Foundation
import CloudKit

/// Helper method to retry a CloudKit operation when its error suggests it
///
/// - Parameters:
///   - error: The error returned from a CloudKit operation
///   - block: A block to be executed after a delay if the error is recoverable
/// - Returns: If the error can't be retried, returns the error
internal func retryCloudKitOperationIfPossible(with error: Error?, block: @escaping () -> ()) -> Error? {
    guard error != nil else { return nil }
    
    guard let effectiveError = error as? CKError else {
        slog("CloudKit puked ¯\\_(ツ)_/¯")
        return error
    }
    
    guard let retryAfter = effectiveError.retryAfterSeconds else {
        slog("CloudKit error: \(effectiveError)")
        return effectiveError
    }
    
    slog("CloudKit operation error, retrying after \(retryAfter) seconds... \(effectiveError)")
    
    DispatchQueue.main.asyncAfter(deadline: .now() + retryAfter) {
        block()
    }
    
    return nil
}

internal func slog(_ format: String, _ args: CVarArg...) {
    #if DEBUG
        NSLog("[CMSCommunityCenter] " + format, args)
    #endif
}
