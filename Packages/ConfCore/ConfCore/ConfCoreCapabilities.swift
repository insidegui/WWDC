//
//  File.swift
//  
//
//  Created by Guilherme Rambo on 02/12/20.
//

import Foundation

@MainActor
public struct ConfCoreCapabilities {
    /// Set this to `true` to enable CloudKit-based features (requires entitlements).
    public static var isCloudKitEnabled = false
}
