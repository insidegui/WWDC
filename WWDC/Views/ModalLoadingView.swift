//
//  ModalLoadingView.swift
//  WWDC
//
//  Created by Guilherme Rambo on 20/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
import SwiftUI

final class ModalLoadingView: NSView {

    private lazy var backgroundView: NSVisualEffectView = {
        let v = NSVisualEffectView()

        v.material = .sidebar
        v.blendingMode = .withinWindow
        v.translatesAutoresizingMaskIntoConstraints = false
        v.state = .active

        return v
    }()

    private lazy var content: NSView = {
        let v = NSHostingView(rootView: LoadingContent())
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        wantsLayer = true

        addSubview(backgroundView)
        backgroundView.addSubview(content)

        backgroundView.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
        backgroundView.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true
        backgroundView.topAnchor.constraint(equalTo: topAnchor).isActive = true
        backgroundView.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true

        content.centerXAnchor.constraint(equalTo: backgroundView.centerXAnchor).isActive = true
        content.centerYAnchor.constraint(equalTo: backgroundView.centerYAnchor).isActive = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    static func show(attachedTo view: NSView) -> ModalLoadingView {
        let v = ModalLoadingView(frame: view.bounds)

        v.show(in: view)

        return v
    }

    func show(in view: NSView) {
        autoresizingMask = [.width, .height]

        view.addSubview(self)
    }

    func hide() {
        removeFromSuperview()
    }

}

private struct LoadingContent: View {
    @State private var animated = false

    var body: some View {
        VStack(spacing: 12) {
            Spinner()
                .opacity(animated ? 1 : 0)

            VStack(spacing: 6) {
                Text("Fetching and Indexing Content")
                    .font(.headline)
                    .foregroundColor(.primary)
                    .opacity(animated ? 1 : 0)
                    .delay(1.5)

                Text("This may take a moment the first time the app is launched")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .opacity(animated ? 1 : 0)
                    .delay(3)
            }
        }
        .onAppear {
            withAnimation(.easeIn(duration: 1)) {
                animated = true
            }
        }
    }
}

private struct Spinner: NSViewRepresentable {
    typealias NSViewType = NSProgressIndicator

    func makeNSView(context: Context) -> NSProgressIndicator {
        let v = NSProgressIndicator()

        v.style = .spinning
        v.isIndeterminate = true
        v.startAnimation(nil)

        return v
    }

    func updateNSView(_ nsView: NSProgressIndicator, context: Context) {

    }
}

private extension View {
    func delay(_ time: TimeInterval) -> some View {
        transaction { t in
            t.animation = t.animation?.delay(time)
        }
    }
}
