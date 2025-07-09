//
//  WWDCTextButton.swift
//  WWDC
//
//  Created by Guilherme Rambo on 28/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
import SwiftUI

struct WWDCTextButtonStyle: ButtonStyle {
    let isSelected: Bool

    @State var isHovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: isSelected ? .medium : .regular))
            .foregroundStyle(AnyShapeStyle(foregroundColor(configuration)))
            .padding(.vertical, 8)
            .padding(.horizontal, 8)
            .animation(.snappy, value: configuration.isPressed)
            .onHover { isHovering in
                self.isHovering = isHovering
            }
            .background {
                if isHovering {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.2))
                }
            }
            .drawingGroup()
    }

    func foregroundColor(_ configuration: Configuration) -> any ShapeStyle {
        let baseColor: any ShapeStyle = if isSelected {
            Color(nsColor: .primary)
        } else {
            .tertiary
        }

        if configuration.isPressed {
            return baseColor.opacity(0.5)
        } else {
            return baseColor
        }
    }
}
