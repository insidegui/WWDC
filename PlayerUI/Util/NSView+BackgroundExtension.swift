//
//  NSView+BackgroundExtension.swift
//  WWDC
//
//  Created by luca on 11.08.2025.
//  Copyright © 2025 Guilherme Rambo. All rights reserved.
//

import AppKit
import SwiftUI

public extension NSView {
    func backgroundExtensionEffect(reflect edges: Edge.Set = .all, isEnabled: Bool = true) -> NSView {
        if isEnabled, #available(macOS 26.0, *) {
            let extensionView = NSBackgroundExtensionView()
            extensionView.contentView = self
            extensionView.automaticallyPlacesContentView = false
            extensionView.translatesAutoresizingMaskIntoConstraints = false
            // only enable reflection effect on leading edge
            let targetLeadingAnchor = edges.contains(.leading) ? extensionView.safeAreaLayoutGuide.leadingAnchor : extensionView.leadingAnchor
            let targetTopAnchor = edges.contains(.top) ? extensionView.safeAreaLayoutGuide.topAnchor : extensionView.topAnchor
            let targetTrailingAnchor = edges.contains(.trailing) ? extensionView.safeAreaLayoutGuide.trailingAnchor : extensionView.trailingAnchor
            let targetBottomAnchor = edges.contains(.bottom) ? extensionView.safeAreaLayoutGuide.bottomAnchor : extensionView.bottomAnchor
            NSLayoutConstraint.activate([
                topAnchor.constraint(equalTo: targetTopAnchor),
                leadingAnchor.constraint(equalTo: targetLeadingAnchor),
                bottomAnchor.constraint(equalTo: targetBottomAnchor),
                trailingAnchor.constraint(equalTo: targetTrailingAnchor)
            ])
            return extensionView
        } else {
            return self
        }
    }

    @available(macOS 26.0, *)
    func glassEffect(style: NSGlassEffectView.Style? = nil, cornerRadius: CGFloat? = nil, tintColor: NSColor? = nil) -> NSView {
        let effectView = NSGlassEffectView()
        if let cornerRadius {
            effectView.cornerRadius = cornerRadius
        }
        if let style {
            effectView.style = style
        }
        effectView.contentView = self
        effectView.tintColor = tintColor
        return effectView
    }

    // will be bridged to swiftui and back
    @available(macOS 26.0, *)
    func glassCapsuleEffect(_ glass: Glass = .clear, tint: Color? = .black.opacity(0.3)) -> NSView {
        NSHostingView(rootView: ViewWrapper(view: self).glassEffect(glass, in: .capsule).tint(tint))
    }

    // will be bridged to swiftui and back
    @available(macOS 26.0, *)
    func glassCircleEffect(_ glass: Glass = .clear, tint: Color? = .black.opacity(0.3), pading: CGFloat? = nil) -> NSView {
        NSHostingView(rootView: ViewWrapper(view: self).padding(.all, pading).glassEffect(glass, in: .circle).tint(tint))
    }

    @available(macOS 26.0, *)
    func glassContainer(spacing: CGFloat? = nil) -> NSView {
        let effectView = NSGlassEffectContainerView()
        effectView.spacing = spacing ?? 0
        effectView.contentView = self
        return effectView
    }
}

private struct ViewWrapper: NSViewRepresentable {
    let view: NSView
    func makeNSView(context: Context) -> NSView {
        view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

//@available(macOS 26.0, *)
//class StatefulGlassView<Control: StatefulControl>: NSControl, StatefulControl {
//    var state: NSControl.StateValue {
//        get { wrapped?.state ?? .off }
//        set { wrapped?.state = newValue }
//    }
//    var wrapped: Control?
//    var host: NSView?
//
//    init(control: Control, glass: Glass = .clear, tint: Color? = .black.opacity(0.3)) {
//        wrapped = control
//        host = NSHostingView(rootView: ViewWrapper(view: self).glassEffect(glass, in: .circle).tint(tint))
//        super.init(frame: .zero)
//        setup()
//    }
//
//    required init?(coder: NSCoder) {
//        super.init(coder: coder)
//        setup()
//    }
//
//    private func setup() {
//        guard let host else {
//            return
//        }
//        host.translatesAutoresizingMaskIntoConstraints = false
//        addSubview(host)
//        NSLayoutConstraint.activate([
//            host.leadingAnchor.constraint(equalTo: leadingAnchor),
//            host.trailingAnchor.constraint(equalTo: trailingAnchor),
//            host.topAnchor.constraint(equalTo: topAnchor),
//            host.bottomAnchor.constraint(equalTo: bottomAnchor)
//        ])
//    }
//
//}
