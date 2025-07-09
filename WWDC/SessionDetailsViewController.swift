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
            cancellables = []

            viewModel?.rxTranscriptUpdated.replaceError(with: "").sink { [weak self] _ in
                self?.isTranscriptAvailable = self?.viewModel?.session.transcript() != nil
            }
            .store(in: &cancellables)

            shelfController.viewModel = viewModel
            summaryController.viewModel = viewModel
            transcriptController.viewModel = viewModel

            guard let viewModel = viewModel else {
                return
            }

            if viewModel.identifier != oldValue?.identifier {
                selectedTab = .overview
            }

            isTranscriptAvailable = viewModel.session.transcript() != nil
            isBookmarksAvailable = false
        }
    }

    @Published var isTranscriptAvailable: Bool = false
    @Published var isBookmarksAvailable: Bool = false
    @Published var selectedTab: SessionTab = .overview
    
    let shelfController: ShelfViewController
    let summaryController: SessionSummaryViewController
    let transcriptController: SessionTranscriptViewController
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        shelfController = ShelfViewController()
        summaryController = SessionSummaryViewController()
        transcriptController = SessionTranscriptViewController()
    }
}

extension SessionDetailsViewModel {
    enum SessionTab {
        case overview, transcript, bookmarks
    }
}

final class SessionDetailsViewController: NSViewController {

    private struct Metrics {
        static let padding: CGFloat = 46
    }

    let detailsViewModel = SessionDetailsViewModel()

    var viewModel: SessionViewModel? {
        didSet {
            view.animator().alphaValue = (viewModel == nil) ? 0 : 1
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
}
