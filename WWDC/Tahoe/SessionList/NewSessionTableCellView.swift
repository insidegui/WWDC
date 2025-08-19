//
//  NewSessionTableCellView.swift
//  WWDC
//
//  Created by luca on 09.08.2025.
//  Copyright © 2025 Guilherme Rambo. All rights reserved.
//

import AppKit
import SwiftUI

final class NewSessionTableCellView: NSTableCellView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        setup()
    }

    var viewModel: SessionViewModel? {
        get {
            return cellViewModel.session
        }
        set {
            cellViewModel.session = newValue
        }
    }

    @available(*, unavailable)
    required init?(coder decoder: NSCoder) {
        fatalError()
    }

    private lazy var cellViewModel = SessionItemViewModel()
    
    private lazy var hostingView: NSView = {
        return NSHostingView(rootView: SessionItemViewForSidebar().environment(cellViewModel))
    }()

    private func setup() {
        hostingView.autoresizingMask = [.width, .height]
        addSubview(hostingView)
    }
}
