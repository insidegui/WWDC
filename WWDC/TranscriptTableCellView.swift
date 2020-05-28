//
//  TranscriptTableCellView.swift
//  WWDC
//
//  Created by Guilherme Rambo on 29/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
import ConfCore
import PlayerUI

class TranscriptTableCellView: NSTableCellView {

    var annotation: TranscriptAnnotation? {
        didSet {
            updateUI()
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        buildUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private lazy var titleLabel: NSTextField = {
        let l = NSTextField(labelWithString: "")

        l.translatesAutoresizingMaskIntoConstraints = false
        l.font = .systemFont(ofSize: 14, weight: .medium)
        l.textColor = .primaryText
        l.cell?.backgroundStyle = .dark
        l.lineBreakMode = .byTruncatingTail
        l.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        l.setContentHuggingPriority(.defaultLow, for: .horizontal)

        return l
    }()

    private lazy var subtitleLabel: NSTextField = {
        let l = NSTextField(labelWithString: "")

        l.translatesAutoresizingMaskIntoConstraints = false
        l.font = .systemFont(ofSize: 12)
        l.textColor = .secondaryText
        l.cell?.backgroundStyle = .dark
        l.lineBreakMode = .byTruncatingTail

        return l
    }()

    private func buildUI() {
        addSubview(titleLabel)
        addSubview(subtitleLabel)

        titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor).isActive = true
        subtitleLabel.centerYAnchor.constraint(equalTo: centerYAnchor).isActive = true

        subtitleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12).isActive = true
        titleLabel.leadingAnchor.constraint(equalTo: subtitleLabel.trailingAnchor, constant: 8).isActive = true

        titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12).isActive = true
    }

    private func updateUI() {
        guard let annotation = annotation else { return }

        titleLabel.stringValue = annotation.body
        subtitleLabel.stringValue = String(timestamp: annotation.timecode) ?? ""
    }

}
