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

    private lazy var viewModel = HeaderRowViewModel(title: "")

    var title: String {
        get { viewModel.title }
        set { viewModel.title = newValue }
    }

    var symbolName: String? {
        get { viewModel.symbolName }
        set { viewModel.symbolName = newValue }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        update()
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    override func drawSelection(in dirtyRect: NSRect) { }

    override func drawBackground(in dirtyRect: NSRect) { }

    private func update() {

        let bg = NSVisualEffectView(frame: bounds)
        bg.appearance = NSAppearance(named: .darkAqua)
        bg.material = .headerView
        bg.blendingMode = .withinWindow
        bg.state = .followsWindowActiveState
        bg.autoresizingMask = [.width, .height]
        addSubview(bg)

        let v = NSHostingView(rootView: TopicHeaderRowContent().environment(viewModel))
        v.translatesAutoresizingMaskIntoConstraints = false

        bg.addSubview(v)

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

private struct TopicHeaderRowContent: View {
    @Environment(HeaderRowViewModel.self) private var viewModel
    var body: some View {
        HStack {
            if let symbolName = viewModel.symbolName {
                Image(systemName: symbolName)
                    .foregroundStyle(.secondary)
                    .symbolVariant(.fill)
            }

            Text(viewModel.title)
                .font(.headline)
                .foregroundStyle(.primary)
        }
        .padding(.horizontal)
        .frame(maxWidth: .infinity, minHeight: SessionsTableViewController.Metrics.headerRowHeight, maxHeight: SessionsTableViewController.Metrics.headerRowHeight, alignment: .leading)
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
