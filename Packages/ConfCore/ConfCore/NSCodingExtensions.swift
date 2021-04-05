//
//  NSCodingExtensions.swift
//  ConfCore
//
//  Created by Guilherme Rambo on 18/07/19.
//  Copyright © 2019 Guilherme Rambo. All rights reserved.
//

import Foundation
import QuartzCore
import os.log

private let _log = OSLog(subsystem: "ConfCore", category: "NSCodingExtensions")

public extension NSKeyedArchiver {

    static func archiveData(with rootObject: Any, secure: Bool) -> Data {
        do {
            return try NSKeyedArchiver.archivedData(withRootObject: rootObject, requiringSecureCoding: secure)
        } catch {
            assertionFailure("Failed to archive object: \(error)")

            return Data()
        }
    }

}
