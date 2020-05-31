//
//  CommunityTagView.swift
//  WWDC
//
//  Created by Guilherme Rambo on 31/05/20.
//  Copyright © 2020 Guilherme Rambo. All rights reserved.
//

import Cocoa

final class CommunityTagView: NSView {

    var tagType: TagType = .apple {
        didSet {
            updateUI()
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        setup()
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    enum TagType: String {
        case apple
        case community
        case evolution
        case press
        case podcast
        case newsletter

        var displayName: String {
            switch self {
            case .apple: return "APPLE"
            case .community: return "COMMUNITY"
            case .evolution: return "EVOLUTION"
            case .press: return "PRESS"
            case .podcast: return "PODCAST"
            case .newsletter: return "NEWSLETTER"
            }
        }

        var color: NSColor? { NSColor(named: .init("tagColor-" + rawValue)) }
    }

    private lazy var label: NSTextField = {
        let v = NSTextField(labelWithString: "")

        v.translatesAutoresizingMaskIntoConstraints = false
        v.font = NSFont.systemFont(ofSize: 10, weight: .medium)
        v.textColor = .white
        v.maximumNumberOfLines = 1
        v.setContentCompressionResistancePriority(.required, for: .horizontal)

        return v
    }()

    private struct Metrics {
        static let padding: CGFloat = 7
    }

    private func setup() {
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.cornerCurve = .continuous
        layer?.cornerRadius = 4

        addSubview(label)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Metrics.padding),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Metrics.padding),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            heightAnchor.constraint(equalToConstant: 18)
        ])

        updateUI()
    }

    private func updateUI() {
        label.stringValue = tagType.displayName
        layer?.backgroundColor = tagType.color?.cgColor
    }
    
}
