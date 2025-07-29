//
//  TahoeFeatureFlag.swift
//  WWDC
//
//  Created by luca on 29.07.2025.
//  Copyright © 2025 Guilherme Rambo. All rights reserved.
//

import Foundation
import SwiftUI

final class TahoeFeatureFlag: ObservableObject {
    /*@MainActor */static var isLiquidGlassEnabled: Bool {
        get {
            shared.isLiquidGlassEnabled
        }
        set {
            shared.isLiquidGlassEnabled = newValue
        }
    }
    /*@MainActor */private static let shared = TahoeFeatureFlag()

    @AppStorage("TahoeFeatureFlag.isLiquidGlassEnabled")
    var isLiquidGlassEnabled = false
}
