//
//  ShelfView.swift
//  WWDC
//
//  Created by Guilherme Rambo on 22/04/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
import SwiftUI

final class ShelfView: NSView, ObservableObject {

    static var defaultPadding: CGFloat { 22 }

    @Published var image: NSImage?
    @Published var padding: CGFloat = ShelfView.defaultPadding

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        wantsLayer = true

        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    convenience init(image: NSImage, padding: CGFloat = ShelfView.defaultPadding) {
        self.init(frame: .zero)

        self.image = image
        self.padding = padding
    }

    private func setup() {
        let host = NSHostingView(rootView: ContentView(shelf: self))
        host.translatesAutoresizingMaskIntoConstraints = false
        addSubview(host)

        NSLayoutConstraint.activate([
            host.leadingAnchor.constraint(equalTo: leadingAnchor),
            host.trailingAnchor.constraint(equalTo: trailingAnchor),
            host.topAnchor.constraint(equalTo: topAnchor),
            host.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    private struct ContentView: View {
        @ObservedObject var shelf: ShelfView
        @State private var image: Image?

        var body: some View {
            let image = shelf.image.flatMap { Image(nsImage: $0) }
            ZStack {
                if let image {
                    let base = image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

                    base
                        .saturation(1.3)
                        .brightness(-0.3)
                        .blur(radius: 44)
                        .opacity(0.8)

                    base
                        .shadow(color: .black.opacity(0.1), radius: 10)
                        .shadow(color: .black.opacity(0.2), radius: 1)
                }
            }
            .padding(shelf.padding)
        }
    }
}

#if DEBUG
#Preview("Wider", traits: .fixedLayout(width: 600, height: 300)) {
    ShelfView(
        image: .init(resource: .previewVideoPoster)
    )
}

#Preview("Matching", traits: .fixedLayout(width: 640, height: 360)) {
    ShelfView(
        image: .init(resource: .previewVideoPoster)
    )
}
#endif
