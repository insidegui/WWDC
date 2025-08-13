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
    func glassCapsuleEffect(_ glass: Glass = .regular, background: Color? = nil) -> NSView {
        NSHostingView(rootView: ConditionalGlassViewWrapper(subview: self, glass: glass, background: background, padding: nil, shape: .capsule))
    }

    // will be bridged to swiftui and back
    @available(macOS 26.0, *)
    func glassCircleEffect(_ glass: Glass = .regular, background: Color? = nil, padding: CGFloat? = nil) -> NSView {
        NSHostingView(rootView: ConditionalGlassViewWrapper(subview: self, glass: glass, background: background, padding: padding, shape: .circle))
    }

    @available(macOS 26.0, *)
    static func horizontalGlassContainer(_ glass: Glass = .regular, background: Color? = nil, paddingEdge: Edge.Set = .all, padding: CGFloat? = nil, containerSpacing: CGFloat? = nil, spacing: CGFloat? = nil, groups: [[NSView]]) -> NSView {
        NSHostingView(rootView: GroupedHorizontalGlassContainer(axis: .horizontal, subviewGroups: groups, containerSpacing: containerSpacing, spacing: spacing, glass: glass, background: background, paddingEdge: paddingEdge, padding: padding, shape: .capsule))
    }

    @available(macOS 26.0, *)
    static func verticalGlassContainer(_ glass: Glass = .regular, background: Color? = nil, paddingEdge: Edge.Set = .all, padding: CGFloat? = nil, containerSpacing: CGFloat? = nil, spacing: CGFloat? = nil, groups: [[NSView]]) -> NSView {
        NSHostingView(rootView: GroupedHorizontalGlassContainer(axis: .vertical, subviewGroups: groups, containerSpacing: containerSpacing, spacing: spacing, glass: glass, background: background, paddingEdge: paddingEdge, padding: padding, shape: .capsule))
    }
}

@available(macOS 26.0, *)
private struct GroupedHorizontalGlassContainer<S: Shape>: View {
    let axis: Axis.Set
    let subviewGroups: [[NSView]]
    let containerSpacing: CGFloat?
    let spacing: CGFloat?
    let glass: Glass
    let background: Color?
    let paddingEdge: Edge.Set
    let padding: CGFloat?
    let shape: S
    @Namespace private var namespace
    var body: some View {
        GlassEffectContainer(spacing: containerSpacing ?? spacing) {
            Stack(axis: axis, spacing: spacing) {
                ForEach(subviewGroups.indices, id: \.self) { groupIdx in
                    ConditionalHorizontalGlassViewWrapper(
                        axis: axis,
                        subviews: subviewGroups[groupIdx],
                        spacing: spacing,
                        glass: glass,
                        tint: background,
                        paddingEdge: paddingEdge,
                        padding: padding,
                        id: "\(groupIdx)",
                        namespace: namespace,
                        shape: shape
                    )
                }
            }
        }
    }

    @available(macOS 26.0, *)
    private struct ConditionalHorizontalGlassViewWrapper: View {
        let axis: Axis.Set
        let subviews: [NSView]
        let spacing: CGFloat?
        let glass: Glass
        let background: Color?
        let paddingEdge: Edge.Set
        let padding: CGFloat?
        let id: String
        let namespace: Namespace.ID
        let shape: S
        @State private var isSubviewsHidden: [Bool]
        init(axis: Axis.Set, subviews: [NSView], spacing: CGFloat?, glass: Glass, tint: Color?, paddingEdge: Edge.Set, padding: CGFloat?, id: String, namespace: Namespace.ID, shape: S) {
            self.axis = axis
            self.subviews = subviews
            self.spacing = spacing
            self.glass = glass
            self.background = tint
            self.paddingEdge = paddingEdge
            self.padding = padding
            self.isSubviewsHidden = subviews.map(\.isHidden)
            self.id = id
            self.namespace = namespace
            self.shape = shape
        }

        var body: some View {
            Stack(axis: axis, spacing: spacing) {
                ForEach(subviews.indices, id: \.self) { idx in
                    ConditionalViewWrapper(subview: subviews[idx], isHidden: $isSubviewsHidden[idx])
                }
            }
            .padding(paddingEdge, padding)
            .background(isSubviewsHidden.allSatisfy({ $0 }) ? .clear : background)
            .clipShape(shape)
            .glassEffect(isSubviewsHidden.allSatisfy({ $0 }) ? .identity : glass, in: .capsule)
            .glassEffectID(id, in: namespace)
            .opacity(isSubviewsHidden.allSatisfy({ $0 }) ? 0 : 1)
        }
    }
}

extension View {
    @ViewBuilder
    func Stack<Content: View>(axis: Axis.Set, spacing: CGFloat? = nil, @ViewBuilder content: () -> Content) -> some View {
        if axis.contains(.vertical) {
            VStack(spacing: spacing, content: content)
        } else {
            HStack(spacing: spacing, content: content)
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

@available(macOS 26.0, *)
private struct ConditionalGlassViewWrapper<S: Shape>: View {
    let subview: NSView
    let glass: Glass
    let background: Color?
    let padding: CGFloat?
    let shape: S
    @State private var isSubviewHidden: Bool = false
    var isHidden: Binding<Bool>?
    var body: some View {
        Group {
            if !isSubviewHidden {
                ViewWrapper(view: subview)
                    .padding(.all, padding)
                    .background(background)
                    .clipShape(shape)
                    .glassEffect(glass, in: shape)
                    .help(subview.toolTip ?? "")
                    .transition(.blurReplace)
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
