//
//  TopicHeaderRow.swift
//  WWDC
//
//  Created by luca on 02.08.2025.
//  Copyright © 2025 Guilherme Rambo. All rights reserved.
//

import Cocoa
import SwiftUI

@available(macOS 15.0, *)
final class NewTopicHeaderRow: NSTableRowView {
    private lazy var viewModel = HeaderRowViewModel(title: "")

    var title: String {
        get {
            viewModel.title
        }
        set {
            viewModel.title = newValue
        }
    }

    var symbolName: String? {
        get {
            viewModel.symbolName
        }
        set {
            viewModel.symbolName = newValue
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

    private func update() {
        let v = NSHostingView(rootView: NewTopicHeaderRowContent().environment(viewModel))
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
private class HeaderRowViewModel {
    var title: String
    var symbolName: String?

    init(title: String, symbolName: String? = nil) {
        self.title = title
        self.symbolName = symbolName
    }
}

@available(macOS 15.0, *)
private struct NewTopicHeaderRowContent: View {
    @Environment(HeaderRowViewModel.self) private var viewModel
    var body: some View {
        HStack {
            if let symbolName = viewModel.symbolName {
                Image(systemName: symbolName)
                    .symbolVariant(.fill)
                    .contentTransition(.symbolEffect(.replace.magic(fallback: .offUp.wholeSymbol), options: .nonRepeating))
                    .transition(.blurReplace)
            }

            Text(viewModel.title)
                .font(.headline)
                .foregroundStyle(.primary)
                .transition(.blurReplace)
        }
        .padding(.horizontal)
        .frame(maxWidth: .infinity, minHeight: SessionsTableViewController.Metrics.headerRowHeight, maxHeight: SessionsTableViewController.Metrics.headerRowHeight, alignment: .leading)
    }
}
