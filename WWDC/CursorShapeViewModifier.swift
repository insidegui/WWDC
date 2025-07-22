//
//  CursorShapeViewModifier.swift
//  WWDC
//
//  Created by Allen Humphreys on 7/11/25.
//  Copyright © 2025 Guilherme Rambo. All rights reserved.
//

import AppKit
import SwiftUI

/// Inside of a scroll view, the push/pop behaves not so great when re-capturing the hover after the scroll view
/// scrolls. Scrolling the scroll view doesn't cancel the hover but it does change the cursor back to an arrow.
///
/// It may be possible to work around this via onContinuousHover and some cancelling delay shenanigans,
/// but it seems like a lot of effort for a minor issue.
struct CursorShapeViewModifier: ViewModifier {
    let shape: NSCursor.Shape

    func body(content: Content) -> some View {
        content
            .onHover { isHovering in
                if isHovering {
                    shape.cursor.push()
                } else {
                    NSCursor.pop()
                }
            }
    }
}

extension NSCursor {
    enum Shape: CaseIterable {
        case arrow
        case pointingHand
        case closedHand
        case openHand
        case resizeLeft
        case resizeRight
        case resizeLeftRight
        case resizeUp
        case resizeDown
        case resizeUpDown
        case crosshair
        case disappearingItem
        case operationNotAllowed
        case dragLink
        case dragCopy
        case contextualMenu
        case iBeam

        var cursor: NSCursor {
            return switch self {
            case .arrow: .arrow
            case .pointingHand: .pointingHand
            case .closedHand: .closedHand
            case .openHand: .openHand
            case .resizeLeft: .resizeLeft
            case .resizeRight: .resizeRight
            case .resizeLeftRight: .resizeLeftRight
            case .resizeUp: .resizeUp
            case .resizeDown: .resizeDown
            case .resizeUpDown: .resizeUpDown
            case .crosshair: .crosshair
            case .disappearingItem: .disappearingItem
            case .operationNotAllowed: .operationNotAllowed
            case .dragLink: .dragLink
            case .dragCopy: .dragCopy
            case .contextualMenu: .contextualMenu
            case .iBeam: .iBeam
            }
        }
    }
}

extension View {
    @ViewBuilder
    func cursorShape(_ shape: NSCursor.Shape) -> some View {
        modifier(CursorShapeViewModifier(shape: shape))
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 12) {
            ForEach(NSCursor.Shape.allCases, id: \.self) { shape in
                Text("\(String(describing: shape))")
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                    .cursorShape(shape)
            }
        }
        .padding()
    }
}
