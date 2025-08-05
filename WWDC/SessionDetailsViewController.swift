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

class SessionDetailsViewModel: ObservableObject {

    var viewModel: SessionViewModel? {
        didSet {
            shelfController.viewModel = viewModel
            summaryController.viewModel = viewModel
            transcriptController.viewModel = viewModel

            guard let viewModel = viewModel else {
                return
            }

            if viewModel.identifier != oldValue?.identifier {
                selectedTab = .overview
            }
            viewModel.rxTranscript.replaceError(with: nil).map {
                $0 != nil
            }
            .assign(to: &$isTranscriptAvailable)

            isBookmarksAvailable = false
        }
    }

    @Published var isTranscriptAvailable: Bool = false
    @Published var isBookmarksAvailable: Bool = false
    @Published var selectedTab: SessionTab = .overview
    
    let shelfController: ShelfViewController
    let summaryController: SessionSummaryViewController
    let transcriptController: SessionTranscriptViewController
    
    init(session: SessionViewModel? = nil) {
        self.shelfController = ShelfViewController()
        self.summaryController = SessionSummaryViewController()
        self.transcriptController = SessionTranscriptViewController()

        defer {
            self.viewModel = session
        }
    }
}

extension SessionDetailsViewModel {
    enum SessionTab: CaseIterable {
        case overview, transcript, bookmarks
    }
}

final class SessionDetailsViewController: NSViewController {

    private let detailsViewModel = SessionDetailsViewModel()

    var viewModel: SessionViewModel? {
        didSet {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.35
                view.animator().alphaValue = (viewModel == nil) ? 0 : 1
            }
            detailsViewModel.viewModel = viewModel
        }
    }

    var shelfController: ShelfViewController { detailsViewModel.shelfController }
    var summaryController: SessionSummaryViewController { detailsViewModel.summaryController }
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
        view.frame = NSRect(x: 0, y: 0, width: MainWindowController.defaultRect.width - 300, height: MainWindowController.defaultRect.height)
        view.wantsLayer = true
    }

    var searchCoordinator: NewGlobalSearchCoordinator!
    override func viewWillDisappear() {
        super.viewWillDisappear()
        if #available(macOS 26.0, *) {
            hideInspector()
        } else {
            // Fallback on earlier versions
        }
    }
}
