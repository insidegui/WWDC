//
//  CommunityCollectionViewItem.swift
//  WWDC
//
//  Created by Guilherme Rambo on 31/05/20.
//  Copyright © 2020 Guilherme Rambo. All rights reserved.
//

import Cocoa
import ConfCore

final class CommunityCollectionViewItem: NSCollectionViewItem {

    var clickHandler: () -> Void = { }

    var newsItem: CommunityNewsItemViewModel? {
        get { itemView.newsItem }
        set { itemView.newsItem = newValue }
    }

    private lazy var itemView: CommunityNewsItemView = {
        let v = CommunityNewsItemView()

        v.translatesAutoresizingMaskIntoConstraints = false

        return v
    }()

    private lazy var contentView = CommunityCollectionContentView(frame: .zero)

    override func loadView() {
        view = CommunityCollectionContentView(frame: .zero)
        contentView.autoresizingMask = [.width, .height]
        view.addSubview(contentView)
        contentView.layer?.cornerCurve = .continuous
        contentView.layer?.cornerRadius = 18
        contentView.layer?.backgroundColor = NSColor.roundedCellBackground.cgColor

        contentView.addSubview(itemView)

        NSLayoutConstraint.activate([
            itemView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 22),
            itemView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -22),
            itemView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 22),
            itemView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -22)
        ])

        let click = NSClickGestureRecognizer(target: self, action: #selector(clicked))
        view.addGestureRecognizer(click)
    }

    @objc private func clicked() {
        clickHandler()
    }
    
}

fileprivate final class CommunityCollectionContentView: NSView {

    override var isOpaque: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

}
