//
//  TopicHeaderRow.swift
//  WWDC
//
//  Created by Guilherme Rambo on 26/05/23.
//  Copyright © 2023 Guilherme Rambo. All rights reserved.
//

import Cocoa
import SwiftUI

final class TopicHeaderRow: NSTableRowView {

    var content: TopicHeaderRowContent? {
        didSet {
            guard content != oldValue else { return }

            update()
        }
    }

    var title: String? {
        didSet {
            guard title != oldValue else { return }
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    override func drawSelection(in dirtyRect: NSRect) { }

    override func drawBackground(in dirtyRect: NSRect) { }

    private var contentView: NSHostingView<TopicHeaderRowContent>?

    private func update() {
        guard let content else {
            contentView?.isHidden = true
            return
        }

        if let contentView {
            contentView.rootView = content
            contentView.isHidden = false
            return
        }

        let v = NSHostingView(rootView: content)
        v.translatesAutoresizingMaskIntoConstraints = false

        addSubview(v)

        NSLayoutConstraint.activate([
            v.leadingAnchor.constraint(equalTo: leadingAnchor),
            v.trailingAnchor.constraint(equalTo: trailingAnchor),
            v.topAnchor.constraint(equalTo: topAnchor),
            v.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        contentView = v
    }

}

struct TopicHeaderRowContent: View, Hashable {
    var title: String
    var symbolName: String

    var body: some View {
        HStack {
            Image(systemName: symbolName)
                .foregroundStyle(.secondary)

            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)
        }
        .padding(.horizontal)
        .frame(maxWidth: .infinity, minHeight: SessionsTableViewController.Metrics.headerRowHeight, maxHeight: SessionsTableViewController.Metrics.headerRowHeight, alignment: .leading)
        .background(Material.thin, in: Rectangle())
        .overlay {
            let divider = Color.black.frame(height: 1)
                .opacity(0.3)
            VStack {
                divider

                Spacer()

                divider
            }
        }
    }
}
