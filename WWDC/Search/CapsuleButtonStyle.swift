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
    static var capsuleButton: CapsuleButtonStyle {
        capsuleButton(glassy: false)
    }

    static func capsuleButton(tint: Color? = nil, trailingIcon: Image? = nil, glassy: Bool, hoveringAlpha: CGFloat = 0.3, horizontalPadding: CGFloat = 10) -> CapsuleButtonStyle {
        CapsuleButtonStyle(tint: tint, trailingIcon: trailingIcon, glassy: glassy, hoveringAlpha: hoveringAlpha, horizontalPadding: horizontalPadding)
    }
}

@available(macOS 26.0, *)
struct CapsuleButtonStyle: ButtonStyle {
    var tint: Color?
    var trailingIcon: Image?
    var glassy: Bool = false
    var hoveringAlpha: CGFloat = 0.3
    var horizontalPadding: CGFloat = 10
    @State private var isHovered = false
    func makeBody(configuration: Configuration) -> some View {
        GeometryReader { geometry in
            ZStack {
                backgroundColor(isPressed: configuration.isPressed)
                    .contentShape(Rectangle()) // expand hit test rect for menus
//                    .clipShape(RoundedRectangle(cornerRadius: geometry.size.height * 0.5))
                    .clipShape(ConcentricRectangle(corners: .concentric(minimum: 10), isUniform: true))

                HStack {
                    configuration.label
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(1)
                    if let trailingIcon {
                        Spacer()
                        trailingIcon
                    }
                }
//                .padding(.horizontal, horizontalPadding)
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .center)
            .animation(.bouncy, value: configuration.isPressed)
        }
        .onHover { isHovering in
            withAnimation {
                isHovered = isHovering
            }
        }
    }

    private func backgroundColor(isPressed: Bool) -> Color {
        if isHovered || isPressed {
            return (tint ?? .secondary).opacity(hoveringAlpha)
        } else {
            return tint ?? .clear
        }
    }
}
