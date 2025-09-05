//
//  View+Extensions.swift
//  WWDC
//
//  Created by Allen Humphreys on 9/3/25.
//  Copyright © 2025 Guilherme Rambo. All rights reserved.
//

import SwiftUI

extension View {
    func synchronize<Value: Equatable>(
        _ first: Binding<Value>,
        _ second: FocusState<Value>.Binding
    ) -> some View {
        self
            .onChange(of: first.wrappedValue) { newValue, _ in second.wrappedValue = newValue }
            .onChange(of: second.wrappedValue) { newValue, _ in first.wrappedValue = newValue }
    }
}
