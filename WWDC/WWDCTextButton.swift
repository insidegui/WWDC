//
//  WWDCTextButton.swift
//  WWDC
//
//  Created by Guilherme Rambo on 28/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa

class WWDCTextButton: NSButton {

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        configure()
    }

    override var title: String {
        didSet {
            configure()
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configure() {
        isBordered = false

        if state == .on {
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 16, weight: .medium),
                .foregroundColor: NSColor.primary
            ]

            attributedTitle = NSAttributedString(string: title, attributes: attrs)
        } else {
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 16),
                .foregroundColor: NSColor.tertiaryText
            ]

            attributedTitle = NSAttributedString(string: title, attributes: attrs)
        }

        sizeToFit()

        cell?.backgroundStyle = .dark
    }

    override var state: NSControl.StateValue {
        didSet {
            configure()
        }
    }

}
