//
//  IsSelected.swift
//  WWDC
//
//  Created by Allen Humphreys on 7/10/25.
//  Copyright © 2025 Guilherme Rambo. All rights reserved.
//

import SwiftUI

struct IsSelectedEnvironmentKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    var isSelected: Bool {
        get { self[IsSelectedEnvironmentKey.self] }
        set { self[IsSelectedEnvironmentKey.self] = newValue }
    }
}

extension View {
    /// Similar to `enabled(_:)`, but for selection state.
    func selected(_ isSelected: Bool) -> some View {
        environment(\.isSelected, isSelected)
    }
}
