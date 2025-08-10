//
//  HoverEffect.swift
//  WWDC
//
//  Created by luca on 10.08.2025.
//  Copyright © 2025 Guilherme Rambo. All rights reserved.
//

import SwiftUI

extension View {
    func hoverEffect(scale: Double = 1.2) -> some View {
        modifier(HoverEffect(hoverScale: scale))
    }
}

struct HoverEffect: ViewModifier {
    @State private var isHovered: Bool = false
    var hoverScale: Double

    func body(content: Content) -> some View {
        content
            .scaleEffect(isHovered ? hoverScale : 1)
            .animation(.smooth, value: isHovered)
            .onHover { isHovering in
                withAnimation {
                    isHovered = isHovering
                }
            }
    }
}
