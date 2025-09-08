//
//  SessionDetailsViewModel.swift
//  WWDC
//
//  Created by Allen Humphreys on 7/18/25.
//  Copyright © 2025 Guilherme Rambo. All rights reserved.
//

import Combine

class SessionDetailsViewModel: ObservableObject {
    @MainActor
    var session: SessionViewModel? {
        didSet {
            if session?.identifier != oldValue?.identifier {
                selectedTab = .overview
            }

            updateBindings()
        }
    }

    @Published var isTranscriptAvailable: Bool = false
    @Published var isBookmarksAvailable: Bool = false
    @Published var selectedTab: SessionTab = .overview
    
    let shelfController: ShelfViewController
    let summaryViewModel: SessionSummaryViewModel
    let transcriptController: SessionTranscriptViewController

    private var cancellables: [AnyCancellable] = []

    @MainActor
    init(session: SessionViewModel? = nil) {
        self.shelfController = ShelfViewController()
        self.summaryViewModel = SessionSummaryViewModel()
        self.transcriptController = SessionTranscriptViewController()

        defer {
            self.session = session
        }
    }

    @MainActor
    func updateBindings() {
        cancellables = []

        shelfController.viewModel = session
        summaryViewModel.session = session
        transcriptController.viewModel = session

        guard let session else { return }
        session.connect()

        isTranscriptAvailable = !session.transcriptText.isEmpty
        session.$transcriptText
            .map(\.isEmpty)
            .toggled()
            .weakAssign(to: \.isTranscriptAvailable, on: self)
            .store(in: &cancellables)
    }
}

extension SessionDetailsViewModel {
    enum SessionTab {
        case overview, transcript, bookmarks
    }
}
