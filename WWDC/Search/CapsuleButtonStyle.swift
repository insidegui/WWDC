//
//  CapsuleButtonStyle.swift
//  WWDC
//
//  Created by luca on 02.08.2025.
//  Copyright © 2025 Guilherme Rambo. All rights reserved.
//

import SwiftUI

@available(macOS 26.0, *)
extension ButtonStyle where Self == CapsuleButtonStyle {
    static func capsuleButton(highlighted: Bool, highlightedColor: Color? = nil, trailingIcon: Image? = nil, hoveringAlpha: CGFloat = 0.3, horizontalPadding: CGFloat = 10) -> CapsuleButtonStyle {
        CapsuleButtonStyle(highlighted: highlighted, highlightedColor: highlightedColor, trailingIcon: trailingIcon, hoveringAlpha: hoveringAlpha, horizontalPadding: horizontalPadding)
    }
}

@available(macOS 26.0, *)
struct CapsuleButtonStyle: ButtonStyle {
    var highlighted: Bool
    var highlightedColor: Color?
    var trailingIcon: Image?
    var hoveringAlpha: CGFloat = 0.3
    var horizontalPadding: CGFloat = 10
    @State private var isHovered = false
    func makeBody(configuration: Configuration) -> some View {
        ZStack {
            backgroundColor(isPressed: configuration.isPressed)
                .contentShape(.capsule) // expand hit test rect for menus
                .clipShape(.capsule)

            HStack {
                configuration.label
                    .multilineTextAlignment(.leading)
                    .lineLimit(1)
                if let trailingIcon {
                    Spacer()
                    trailingIcon
                }
            }
            .foregroundStyle(highlighted ? .white : .primary)
            .padding(.horizontal, horizontalPadding)
        }
        .animation(.bouncy, value: configuration.isPressed)
        .onHover { isHovering in
            withAnimation {
                isHovered = isHovering
            }
        }
    }

    @ViewBuilder
    private func backgroundColor(isPressed: Bool) -> some View {
        (highlighted ? (highlightedColor ?? Color.accentColor) : Color.secondary.opacity(0.3))
            .opacity((isHovered || isPressed) ? hoveringAlpha : 1)
    }
}
