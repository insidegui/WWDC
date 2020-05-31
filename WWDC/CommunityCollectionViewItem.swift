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

    var newsItem: CommunityNewsItem? {
        get { itemView.newsItem }
        set { itemView.newsItem = newValue }
    }

    private lazy var itemView: CommunityNewsItemView = {
        let v = CommunityNewsItemView()

        v.translatesAutoresizingMaskIntoConstraints = false

        return v
    }()

    override func loadView() {
        view = NSView()
        view.wantsLayer = true
        view.layer?.cornerCurve = .continuous
        view.layer?.cornerRadius = 18
        view.layer?.backgroundColor = NSColor.roundedCellBackground.cgColor

        view.addSubview(itemView)

        NSLayoutConstraint.activate([
            itemView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 22),
            itemView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -22),
            itemView.topAnchor.constraint(equalTo: view.topAnchor, constant: 22),
            itemView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -22)
        ])
    }
    
}
