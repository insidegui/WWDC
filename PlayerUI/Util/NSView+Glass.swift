//
//  NSView+Glass.swift
//  WWDC
//
//  Created by luca on 12.08.2025.
//  Copyright © 2025 Guilherme Rambo. All rights reserved.
//

import AppKit
import SwiftUI

public extension NSView {
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
    func glassCapsuleEffect(_ glass: Glass = .regular, tint: Color? = nil) -> NSView {
        NSHostingView(rootView: ViewWrapper(view: self).glassEffect(glass, in: .capsule).tint(tint))
    }

    // will be bridged to swiftui and back
    @available(macOS 26.0, *)
    func glassCircleEffect(_ glass: Glass = .regular, tint: Color? = nil, padding: CGFloat? = nil) -> NSView {
        NSHostingView(rootView: ViewWrapper(view: self).padding(.all, padding).glassEffect(glass, in: .circle).tint(tint))
    }

    @available(macOS 26.0, *)
    static func horizontalGlassContainer(_ glass: Glass = .regular, tint: Color? = nil, padding: CGFloat? = nil, spacing: CGFloat? = nil, groups: [[NSView]]) -> NSView {
        NSHostingView(rootView: GroupedHorizontalGlassContainer(subviewGroups: groups, spacing: spacing, glass: glass, tint: tint, padding: padding))
    }
}

@available(macOS 26.0, *)
private struct GroupedHorizontalGlassContainer: View {
    let subviewGroups: [[NSView]]
    let spacing: CGFloat?
    let glass: Glass
    let tint: Color?
    let padding: CGFloat?
    @Namespace private var namespace
    var body: some View {
        GlassEffectContainer(spacing: spacing) {
            HStack(spacing: spacing) {
                ForEach(subviewGroups.indices, id: \.self) { groupIdx in
                    ConditionalHorizontalGlassViewWrapper(
                        subviews: subviewGroups[groupIdx],
                        spacing: spacing,
                        glass: glass,
                        tint: tint,
                        padding: padding,
                        id: "\(groupIdx)",
                        namespace: namespace
                    )
                }
            }
        }
    }

    @available(macOS 26.0, *)
    private struct ConditionalHorizontalGlassViewWrapper: View {
        let subviews: [NSView]
        let spacing: CGFloat?
        let glass: Glass
        let tint: Color?
        let padding: CGFloat?
        let id: String
        let namespace: Namespace.ID
        @State private var isSubviewsHidden: [Bool]
        init(subviews: [NSView], spacing: CGFloat?, glass: Glass, tint: Color?, padding: CGFloat?, id: String, namespace: Namespace.ID) {
            self.subviews = subviews
            self.spacing = spacing
            self.glass = glass
            self.tint = tint
            self.padding = padding
            self.isSubviewsHidden = subviews.map(\.isHidden)
            self.id = id
            self.namespace = namespace
        }

        var body: some View {
            if isSubviewsHidden.contains(where: { !$0 }) { // not all is hidden
                HStack {
                    ForEach(subviews.indices, id: \.self) { idx in
                        ConditionalViewWrapper(subview: subviews[idx], isHidden: $isSubviewsHidden[idx])
                    }
                }
                .padding(.all, padding)
                .glassEffect(glass, in: .capsule)
                .glassEffectID(id, in: namespace)
                .tint(tint)
            }
        }
    }
}

@available(macOS 26.0, *)
private struct ConditionalViewWrapper: View {
    let subview: NSView
    @State private var isSubviewHidden: Bool = false
    var isHidden: Binding<Bool>?
    var body: some View {
        Group {
            if !isSubviewHidden {
                ViewWrapper(view: subview)
                    .help(subview.toolTip ?? "")
            }
        }
        .onReceive(subview.publisher(for: \.isHidden).removeDuplicates()) { newValue in
            withAnimation {
                isSubviewHidden = newValue
                isHidden?.wrappedValue = newValue
            }
        }
    }
}

private struct ViewWrapper: NSViewRepresentable {
    let view: NSView
    func makeNSView(context: Context) -> NSView {
        view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
