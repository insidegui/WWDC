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
            detailsViewModel.session = viewModel
        }
    }

    var shelfController: ShelfViewController { detailsViewModel.shelfController }
    var transcriptController: SessionTranscriptViewController { detailsViewModel.transcriptController }

    var actionsDelegate: (any SessionActionsDelegate)? {
        get { detailsViewModel.summaryViewModel.actionsViewModel.delegate }
        set { detailsViewModel.summaryViewModel.actionsViewModel.delegate = newValue }
    }
    var relatedSessionsDelegate: (any RelatedSessionsDelegate)? {
        get { detailsViewModel.summaryViewModel.relatedSessionsViewModel.delegate }
        set { detailsViewModel.summaryViewModel.relatedSessionsViewModel.delegate = newValue }
    }

    init() {
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let swiftUIView = SessionDetailsView(viewModel: detailsViewModel)
        view = NSHostingView(rootView: swiftUIView)
        view.frame = NSRect(x: 0, y: 0, width: MainWindowController.defaultRect.width - 300, height: MainWindowController.defaultRect.height)
        view.wantsLayer = true
    }
}
