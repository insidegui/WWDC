//
//  FilterResetButton.swift
//  WWDC
//
//  Created by luca on 02.08.2025.
//  Copyright © 2025 Guilherme Rambo. All rights reserved.
//

import SwiftUI

@available(macOS 15.0, *)
struct FilterResetButton: View {
    let count: Int
    let action: () -> Void
    @State private var showClearIcon = false
    @State private var contentWidth: CGFloat?
    var body: some View {
        Button {
            action()
        } label: {
            HStack(spacing: 3) {
                Image(systemName: showClearIcon ? "xmark" : "line.3.horizontal.decrease")
                    .contentTransition(.symbolEffect(.replace.magic(fallback: .offUp.wholeSymbol), options: .nonRepeating))
                    .frame(width: 20, height: 20)
                Text("\(count)")
                    .fontDesign(.monospaced)
                    .padding(.horizontal, 4)
                    .foregroundStyle(.primary)
                    .capsuleBackground(Color.secondary)
            }
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.width
            } action: { newValue in
                contentWidth = newValue
            }
        }
        .help("Clear")
        .frame(width: contentWidth.flatMap { $0 + 15 } ?? 70)
        .buttonStyle(.capsuleButton(tint: filterTint, glassy: true, hoveringAlpha: 1, horizontalPadding: 0))
        .onHover { isHovering in
            withAnimation {
                showClearIcon = isHovering
            }
        }
    }

    var filterTint: Color? {
        guard count > 0 else {
            return nil
        }
        return showClearIcon ? .red.opacity(0.5) : .accentColor.opacity(0.5)
    }
}
