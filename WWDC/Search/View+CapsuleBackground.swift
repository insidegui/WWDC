//
//  View+CapsuleBackground.swift
//  WWDC
//
//  Created by luca on 02.08.2025.
//  Copyright © 2025 Guilherme Rambo. All rights reserved.
//

import SwiftUI

extension View {
    @ViewBuilder
    func capsuleBackground<Style: ShapeStyle>(_ style: Style) -> some View {
        background {
            GeometryReader { geometry in
                RoundedRectangle(cornerRadius: geometry.size.height * 0.5)
                    .fill(style)
                    .frame(width: geometry.size.width, height: geometry.size.height, alignment: .center)
            }
        }
    }
}
