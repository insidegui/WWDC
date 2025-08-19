//
//  TahoeFeatureFlag.swift
//  WWDC
//
//  Created by luca on 29.07.2025.
//  Copyright © 2025 Guilherme Rambo. All rights reserved.
//

import Foundation
import SwiftUI

enum TahoeFeatureFlag {
    static var isLiquidGlassAvailable: Bool {
#if compiler(>=6.2) && canImport(FoundationModels)
        return true
#else
        return false
#endif
    }

    static var isLiquidGlassEnabled: Bool {
        get {
            guard isLiquidGlassAvailable else {
                return false
            }
            return UserDefaults.standard.bool(forKey: "TahoeFeatureFlag.isLiquidGlassEnabled")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "TahoeFeatureFlag.isLiquidGlassEnabled")
        }
    }
}
