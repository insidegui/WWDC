//
//  SessionDetailsViewModel.swift
//  WWDC
//
//  Created by Allen Humphreys on 7/18/25.
//  Copyright © 2025 Guilherme Rambo. All rights reserved.
//


class SessionDetailsViewModel: ObservableObject {

    @MainActor
    var viewModel: SessionViewModel? {
        didSet {
            shelfController.viewModel = viewModel
            summaryViewModel.sessionViewModel = viewModel
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
    let summaryViewModel: SessionSummaryViewModel
    let transcriptController: SessionTranscriptViewController

    @MainActor
    init(session: SessionViewModel? = nil) {
        self.shelfController = ShelfViewController()
        self.summaryViewModel = SessionSummaryViewModel()
        self.transcriptController = SessionTranscriptViewController()

        defer {
            self.viewModel = session
        }
    }
}

extension SessionDetailsViewModel {
    enum SessionTab {
        case overview, transcript, bookmarks
    }
}