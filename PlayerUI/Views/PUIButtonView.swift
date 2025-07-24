//
//  PUIButtonView.swift
//  WWDC
//
//  Created by Allen Humphreys on 7/15/25.
//  Copyright © 2025 Guilherme Rambo. All rights reserved.
//

import SwiftUI

/// A SwiftUI view that wraps a `PUIButton` for use in SwiftUI views.
///
/// ## Architecture Overview
/// 
/// This component creates a nested bridging pattern during SwiftUI migration:
///
/// ```
/// ┌─────────────────────────────────────────────────────────┐
/// │ PUIButtonView (SwiftUI)                                 │
/// │  ┌─────────────────────────────────────────────────┐    │
/// │  │ PUIButton (AppKit/NSControl)                    │    │
/// │  │  ┌─────────────────────────────────────────┐    │    │
/// │  │  │ PUIButtonContent (SwiftUI)              │    │    │
/// │  │  │  • Rendering & animations               │    │    │
/// │  │  └─────────────────────────────────────────┘    │    │
/// │  │  • Mouse handling & state management            │    │
/// │  └─────────────────────────────────────────────────┘    │
/// │  • Configuration & action coordination                  │
/// └─────────────────────────────────────────────────────────┘
/// ```
///
/// ## Usage Patterns
///
/// ### Self-Contained (Recommended)
/// ```swift
/// PUIButtonView(configuration: .init(image: myImage)) {
///     // Handle button action
/// }
/// ```
///
/// ### Externally Coordinated
/// ```swift
/// let customButton = PUIButton(frame: .zero)
/// PUIButtonView(button: customButton, configuration: .init(image: myImage)) {
///     // Handle button action
/// }
/// ```
///
/// ## Migration Notes
///
/// This architecture is **intentionally temporary** during the SwiftUI migration process.
/// The complex layering exists because:
/// - `PUIButton` contains sophisticated AppKit functionality that's difficult to replicate
/// - The inner SwiftUI layer provides smooth animations and modern rendering
/// - The outer SwiftUI layer provides idiomatic SwiftUI integration
///
/// **Future Direction**: This will eventually be replaced by a pure SwiftUI implementation
/// once all complex AppKit dependencies are resolved.
public struct PUIButtonView: View {
    @State private var button: PUIButton
    public var configuration = Configuration()
    public var action: () -> Void

    @Environment(\.isEnabled) private var isEnabled

    public init(
        button: @autoclosure () -> PUIButton = PUIButton(frame: .zero),
        _ configuration: Configuration = Configuration(),
        action: @escaping () -> Void
    ) {
        self._button = State(initialValue: button())
        self.configuration = configuration
        self.action = action
    }

    public var body: some View {
        Representable(button: button, action: action)
            .onAppear {
                button.isEnabled = isEnabled
                applyConfiguration(configuration)
            }
            .onChange(of: configuration) { _, newValue in
                applyConfiguration(newValue)
            }
            .onChange(of: isEnabled) { _, newValue in
                button.isEnabled = newValue
            }
    }

    func applyConfiguration(_ config: Configuration) {
        button.shouldAlwaysDrawHighlighted = config.alwaysHighlighted
        button.isToggle = config.isToggle
        button.activeTintColor = config.activeTintColor
        button.tintColor = config.tintColor
        button.image = config.image
        button.alternateImage = config.alternateImage
        button.state = config.state
    }

    public struct Configuration: Hashable {
        public var alwaysHighlighted = false
        public var isToggle = false
        public var activeTintColor: NSColor
        public var tintColor: NSColor
        public var image: NSImage?
        public var alternateImage: NSImage?
        public var state: NSControl.StateValue = .off

        public init(
            alwaysHighlighted: Bool = false,
            isToggle: Bool = false,
            activeTintColor: NSColor? = nil,
            tintColor: NSColor? = nil,
            image: NSImage? = nil,
            alternateImage: NSImage? = nil,
            state: NSControl.StateValue = .off
        ) {
            self.alwaysHighlighted = alwaysHighlighted
            self.isToggle = isToggle
            self.activeTintColor = activeTintColor ?? .playerHighlight
            self.tintColor = tintColor ?? .buttonColor
            self.image = image
            self.alternateImage = alternateImage
            self.state = state
        }

        public static func alwaysHighlighted(image: NSImage? = nil) -> Self {
            Configuration(alwaysHighlighted: true, image: image)
        }
    }

    struct Representable: NSViewRepresentable {
        var button: PUIButton
        var action: () -> Void

        func makeNSView(context: Context) -> PUIButton {
            button.target = context.coordinator
            button.action = #selector(Coordinator.buttonAction)

            return button
        }

        func updateNSView(_ nsView: PUIButton, context: Context) {
            // No updates needed, everything is handled by the button itself
        }

        func makeCoordinator() -> Coordinator {
            Coordinator(parent: self)
        }

        final class Coordinator {
            var parent: Representable

            init(parent: Representable) {
                self.parent = parent
            }

            @objc func buttonAction() {
                parent.action()
            }
        }
    }
}

#Preview {
    PUIButtonView(
        .init(
            alwaysHighlighted: true,
            isToggle: true,
            image: NSImage(named: "NSPlayTemplate")
        )
    ) {
        debugPrint("Button clicked")
    }
    .frame(width: 100, height: 100)
}
