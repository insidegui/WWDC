//
//  CommunitySectionHeaderView.swift
//  WWDC
//
//  Created by Guilherme Rambo on 31/05/20.
//  Copyright © 2020 Guilherme Rambo. All rights reserved.
//

import Cocoa

final class CommunitySectionHeaderView: NSView, NSCollectionViewSectionHeaderView {

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        setup()
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    var title: String {
        get { titleLabel.stringValue }
        set { titleLabel.stringValue = newValue }
    }

    var color: NSColor? {
        get { titleLabel.textColor }
        set { titleLabel.textColor = newValue }
    }

    private lazy var titleLabel: WWDCTextField = {
        let l = WWDCTextField(labelWithString: "")

        l.cell?.backgroundStyle = .dark
        l.lineBreakMode = .byTruncatingTail
        l.maximumNumberOfLines = 1
        l.textColor = .primaryText
        l.font = .boldTitleFont
        l.translatesAutoresizingMaskIntoConstraints = false

        return l
    }()

    private func setup() {
        addSubview(titleLabel)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 38),
            titleLabel.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
    
}
