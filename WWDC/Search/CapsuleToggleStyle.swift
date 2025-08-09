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
    static func capsuleToggle(tint: Color? = nil, trailingIcon: Image? = nil, glassy: Bool = true, hoveringAlpha: CGFloat = 0.3, horizontalPadding: CGFloat = 10) -> CapsuleToggleStyle {
        CapsuleToggleStyle(tint: tint, trailingIcon: trailingIcon, glassy: glassy, hoveringAlpha: hoveringAlpha, horizontalPadding: horizontalPadding)
    }
}

@available(macOS 26.0, *)
struct CapsuleToggleStyle: ToggleStyle {
    var tint: Color?
    var trailingIcon: Image?
    var glassy: Bool = true
    var hoveringAlpha: CGFloat = 0.3
    var horizontalPadding: CGFloat = 10
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            configuration.label
        }
        .buttonStyle(CapsuleButtonStyle(tint: configuration.isOn ? tintColor.opacity(0.5) : nil, trailingIcon: trailingIcon, glassy: glassy, hoveringAlpha: hoveringAlpha, horizontalPadding: horizontalPadding))
        .animation(.bouncy, value: configuration.isOn)
    }

    private var tintColor: Color {
        tint ?? .accentColor
    }
}
