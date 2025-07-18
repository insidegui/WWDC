//
//  SessionDetailsViewController.swift
//  WWDC
//
//  Created by Guilherme Rambo on 22/04/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
import SwiftUI
import Combine

final class SessionDetailsViewController: NSViewController {

    private let detailsViewModel = SessionDetailsViewModel()

    var viewModel: SessionViewModel? {
        didSet {
            view.animator().alphaValue = (viewModel == nil) ? 0 : 1
            detailsViewModel.viewModel = viewModel
        }
    }

    var shelfController: ShelfViewController { detailsViewModel.shelfController }
    var summaryController: SessionSummaryViewModel { detailsViewModel.summaryViewModel }
    var transcriptController: SessionTranscriptViewController { detailsViewModel.transcriptController }

    init() {
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let swiftUIView = SessionDetailsView(detailsViewModel: detailsViewModel)
        view = NSHostingView(rootView: swiftUIView)
        view.setContentCompressionResistancePriority(.required, for: .horizontal)
        view.setContentCompressionResistancePriority(.required, for: .vertical)
        view.frame = NSRect(x: 0, y: 0, width: MainWindowController.defaultRect.width - 300, height: MainWindowController.defaultRect.height)
        view.wantsLayer = true
    }
}
