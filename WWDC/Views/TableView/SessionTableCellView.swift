//
//  SessionTableCellView.swift
//  WWDC
//
//  Created by Guilherme Rambo on 22/04/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
import SwiftUI

final class SessionTableCellView: NSTableCellView {

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        setup()
    }

    var viewModel: SessionViewModel? {
        get {
            return cellViewModel.viewModel
        }
        set {
            cellViewModel.viewModel = newValue
        }
    }

    required init?(coder decoder: NSCoder) {
        fatalError()
    }

    private lazy var cellViewModel = SessionCellViewModel()
    
    private lazy var hostingView: NSHostingView<SessionCellView> = {
        let swiftUIView = SessionCellView(cellViewModel: cellViewModel, style: .flat)
        return NSHostingView(rootView: swiftUIView)
    }()

    private func setup() {
        hostingView.autoresizingMask = [.width, .height]
        addSubview(hostingView)
    }

}
