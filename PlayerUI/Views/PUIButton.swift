//
//  PUIButton.swift
//  PlayerUI
//
//  Created by Guilherme Rambo on 29/04/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
import SwiftUI
import AVKit

public final class PUIButton: NSControl, ObservableObject {

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        setup()
    }

    public required init?(coder: NSCoder) {
        fatalError()
    }

    public var isToggle = false

    var isAVRoutePickerMasquerade = false {
        didSet {
            guard isAVRoutePickerMasquerade != oldValue else { return }
            setupAVRoutePicker()
        }
    }

    @Published public var activeTintColor: NSColor = .playerHighlight

    @Published public var tintColor: NSColor = .buttonColor

    @Published public var state: NSControl.StateValue = .off

    public var showsMenuOnLeftClick = false
    public var showsMenuOnRightClick = false
    public var sendsActionOnMouseDown = false

    @Published public var image: NSImage?

    @Published public var alternateImage: NSImage?

    @Published var metrics = PUIControlMetrics.medium

    @Published fileprivate var shouldDrawHighlighted: Bool = false

    @Published public var shouldAlwaysDrawHighlighted: Bool = false

    public override var isEnabled: Bool {
        didSet {
            objectWillChange.send()
        }
    }

    private func setup() {
        let host = NSHostingView(rootView: PUIButtonContent(button: self))
        host.translatesAutoresizingMaskIntoConstraints = false
        addSubview(host)
        NSLayoutConstraint.activate([
            host.leadingAnchor.constraint(equalTo: leadingAnchor),
            host.trailingAnchor.constraint(equalTo: trailingAnchor),
            host.topAnchor.constraint(equalTo: topAnchor),
            host.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    public override func mouseDown(with event: NSEvent) {
        guard isEnabled else { return }

        guard !showsMenuOnLeftClick else {
            showMenu(with: event)
            return
        }

        shouldDrawHighlighted = true

        if !sendsActionOnMouseDown {
            window?.trackEvents(matching: [.leftMouseUp, .leftMouseDragged], timeout: NSEvent.foreverDuration, mode: .eventTracking) { event, stop in
                if event?.type == .leftMouseUp {
                    self.shouldDrawHighlighted = false
                    stop.pointee = true
                }
            }
        }

        if let action = action, let target = target {
            if isToggle {
                state = (state == .on) ? .off : .on
            }
            NSApp.sendAction(action, to: target, from: self)
        }
    }

    public override func rightMouseDown(with event: NSEvent) {
        guard showsMenuOnRightClick else {
            return
        }
        showMenu(with: event)
    }

    private func showMenu(with event: NSEvent) {
        guard let menu = menu else { return }

        menu.popUp(positioning: nil, at: .zero, in: self)
    }

    public override var allowsVibrancy: Bool { true }

    public override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    // MARK: - AVRoutePickerView

    var player: AVPlayer? {
        get { routePicker.player }
        set { routePicker.player = newValue }
    }

    private lazy var routePicker: AVRoutePickerView = {
        let v = AVRoutePickerView()
        v.setRoutePickerButtonColor(.buttonColor, for: .normal)
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private var installedRoutePicker: AVRoutePickerView?

    private func setupAVRoutePicker() {
        guard isAVRoutePickerMasquerade else {
            installedRoutePicker?.removeFromSuperview()
            return
        }

        addSubview(routePicker)
        NSLayoutConstraint.activate([
            routePicker.leadingAnchor.constraint(equalTo: leadingAnchor),
            routePicker.trailingAnchor.constraint(equalTo: trailingAnchor),
            routePicker.topAnchor.constraint(equalTo: topAnchor),
            routePicker.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        // Hack alert
        routePicker.alphaValue = 0.01
    }

    public override func hitTest(_ point: NSPoint) -> NSView? {
        guard isAVRoutePickerMasquerade else { return super.hitTest(point) }
        return routePicker.subviews.first
    }

}

// MARK: - SwiftUI Content

private struct PUIButtonContent: View {
    @ObservedObject var button: PUIButton

    private var currentImage: Image? {
        if let alternateImage = button.alternateImage, button.state == .on {
            return Image(nsImage: alternateImage.withPlayerMetrics(button.metrics))
        } else if let image = button.image {
            return Image(nsImage: image.withPlayerMetrics(button.metrics))
        } else {
            return nil
        }
    }

    private var foregroundColor: Color {
        guard !button.shouldAlwaysDrawHighlighted else { return Color(nsColor: button.activeTintColor) }
        return Color(nsColor: button.state == .on ? button.activeTintColor : button.tintColor)
    }

    private var opacity: CGFloat {
        guard button.isEnabled else { return 0.5 }

        guard !button.shouldAlwaysDrawHighlighted else { return 1.0 }

        return button.shouldDrawHighlighted ? 0.8 : 1.0
    }

    private var scale: CGFloat {
        guard button.isEnabled, !button.shouldAlwaysDrawHighlighted else { return 1 }

        return button.shouldDrawHighlighted ? 0.9 : 1.0
    }

    var body: some View {
        if let currentImage {
            currentImage
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: button.metrics.controlSize, height: button.metrics.controlSize)
                .foregroundColor(foregroundColor)
                .opacity(opacity)
                .scaleEffect(scale)
        }
    }
}

