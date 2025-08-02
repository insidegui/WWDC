//
//  TopicHeaderRow.swift
//  WWDC
//
//  Created by luca on 02.08.2025.
//  Copyright © 2025 Guilherme Rambo. All rights reserved.
//

import Cocoa
import SwiftUI

final class NewTopicHeaderRow: NSTableRowView {
    private lazy var content = RowContent(title: "", symbolName: nil)

    var title: String {
        get {
            content.title
        }
        set {
            content.title = newValue
        }
    }

    var symbolName: String? {
        get {
            content.symbolName
        }
        set {
            content.symbolName = newValue
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        update()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError()
    }

    override func drawSelection(in dirtyRect: NSRect) {}

    override func drawBackground(in dirtyRect: NSRect) {}

    private var contentView: NSHostingView<NewTopicHeaderRowContent>?

    private func update() {
        let v = NSHostingView(rootView: NewTopicHeaderRowContent().environment(content))
        v.translatesAutoresizingMaskIntoConstraints = false

        addSubview(v)

        NSLayoutConstraint.activate([
            v.leadingAnchor.constraint(equalTo: leadingAnchor),
            v.trailingAnchor.constraint(equalTo: trailingAnchor),
            v.topAnchor.constraint(equalTo: topAnchor),
            v.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
}

@Observable
private class RowContent {
    var title: String
    var symbolName: String?

    init(title: String, symbolName: String? = nil) {
        self.title = title
        self.symbolName = symbolName
    }
}

struct NewTopicHeaderRowContent: View {
    @Environment(RowContent.self) private var content
    var body: some View {
        HStack {
            if let symbolName = content.symbolName {
                Image(systemName: symbolName)
                    .foregroundStyle(.secondary)
                    .symbolVariant(.fill)
            }

            Text(content.title)
                .font(.headline)
                .foregroundStyle(.primary)
        }
        .padding(.horizontal)
        .frame(maxWidth: .infinity, minHeight: SessionsTableViewController.Metrics.headerRowHeight, maxHeight: SessionsTableViewController.Metrics.headerRowHeight, alignment: .leading)
    }
}
