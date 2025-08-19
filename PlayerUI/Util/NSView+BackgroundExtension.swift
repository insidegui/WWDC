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
}
