//
//  SetScrollerStyle.swift
//  WWDC
//
//  Created by Allen Humphreys on 7/11/25.
//  Copyright © 2025 Guilherme Rambo. All rights reserved.
//

import SwiftUI

/// Set the scroller style for a ScrollView.
///
/// Place this in a ScrollView to set the scroller style.
///
/// - SeeAlso:
/// [https://developer.apple.com/documentation/appkit/nsscrollview/scrollerstyle](https://developer.apple.com/documentation/appkit/nsscrollview/scrollerstyle)
struct SetScrollerStyle: NSViewRepresentable {
    let style: NSScroller.Style

    init(_ style: NSScroller.Style) {
        self.style = style
    }

    func makeNSView(context: Context) -> View {
        View(style)
    }

    func updateNSView(_ nsView: View, context: Context) {
        nsView.enclosingScrollView?.scrollerStyle = style
    }

    class View: NSView {
        let style: NSScroller.Style

        init(_ style: NSScroller.Style) {
            self.style = style

            super.init(frame: .zero)

            _ = NotificationCenter.default.addObserver(forName: NSScroller.preferredScrollerStyleDidChangeNotification, object: nil, queue: nil) { [weak self] _ in
                self?.enclosingScrollView?.scrollerStyle = .overlay
            }
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func viewDidMoveToSuperview() {
            super.viewDidMoveToSuperview()

            CATransaction.begin()
            CATransaction.setCompletionBlock { [weak self] in
                self?.enclosingScrollView?.scrollerStyle = .overlay
            }
            CATransaction.commit()
        }
    }
}
