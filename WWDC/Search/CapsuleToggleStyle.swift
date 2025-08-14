//
//  CapsuleToggleStyle.swift
//  WWDC
//
//  Created by luca on 02.08.2025.
//  Copyright © 2025 Guilherme Rambo. All rights reserved.
//

import SwiftUI

@available(macOS 26.0, *)
extension ToggleStyle where Self == CapsuleToggleStyle {
    static func capsuleToggle(trailingIcon: Image? = nil, hoveringAlpha: CGFloat = 0.3, horizontalPadding: CGFloat = 10) -> CapsuleToggleStyle {
        CapsuleToggleStyle(trailingIcon: trailingIcon, hoveringAlpha: hoveringAlpha, horizontalPadding: horizontalPadding)
    }
}

@available(macOS 26.0, *)
struct CapsuleToggleStyle: ToggleStyle {
    var trailingIcon: Image?
    var hoveringAlpha: CGFloat = 0.3
    var horizontalPadding: CGFloat = 10
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            configuration.label
        }
        .buttonStyle(CapsuleButtonStyle(highlighted: configuration.isOn, trailingIcon: trailingIcon, hoveringAlpha: hoveringAlpha, horizontalPadding: horizontalPadding))
        .animation(.bouncy, value: configuration.isOn)
    }
}
