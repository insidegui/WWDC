//
//  SessionListViewModel.swift
//  WWDC
//
//  Created by luca on 06.08.2025.
//  Copyright © 2025 Guilherme Rambo. All rights reserved.
//

import Combine
import SwiftUI

struct SessionListSection: Identifiable, Equatable {
    var id: [String?] {
        [systemSymbol, title]
    }

    let title: String
    let systemSymbol: String?
    var sessions: [Session]

    struct Session: Hashable, Identifiable {
        let id: String
        let model: SessionViewModel

        init(model: SessionViewModel) {
            id = model.sessionIdentifier
            self.model = model
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }

        static func == (lhs: SessionListSection.Session, rhs: SessionListSection.Session) -> Bool {
            lhs.id == rhs.id
        }
    }
}

@Observable class SessionListViewModel {
    @ObservationIgnored let rowProvider: SessionRowProvider
    @ObservationIgnored let initialSelection: SessionIdentifiable?
    @ObservationIgnored let searchCoordinator: GlobalSearchCoordinator

    @ObservationIgnored private var rowsObserver: AnyCancellable?

    var sections: [SessionListSection] = []
    var selectedSession: SessionListSection.Session?

    init(
        rowProvider: SessionRowProvider,
        initialSelection: SessionIdentifiable?,
        searchCoordinator: GlobalSearchCoordinator
    ) {
        self.rowProvider = rowProvider
        self.initialSelection = initialSelection
        self.searchCoordinator = searchCoordinator
        sections = rowProvider.rows?.visibleRows.grouped() ?? []
    }

    func prepareForDisplay() {
        rowsObserver = rowProvider
            .rowsPublisher
            .map { $0.visibleRows.grouped() }
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.updateSections($0)
            }
        rowProvider.startup()
    }

    private func updateSections(_ newSections: [SessionListSection]) {
        sections = newSections
        if selectedSession == nil {
            selectedSession = newSections.flatMap(\.sessions)
                .first(where: { $0.id == initialSelection?.sessionIdentifier })
        }
        if selectedSession == nil {
            selectedSession = newSections.first?.sessions.first
        }
    }
}

private extension Array where Element == SessionRow {
    func grouped() -> [SessionListSection] {
        var sections = [SessionListSection]()
        var currentSection: SessionListSection?

        for row in self {
            switch row.kind {
            case let .sectionHeader(title, symbol):
                currentSection.flatMap { sections.append($0) }
                currentSection = .init(title: title, systemSymbol: symbol, sessions: [])
            case let .session(viewModel):
                currentSection?.sessions.append(.init(model: viewModel))
            }
        }
        currentSection.flatMap { sections.append($0) }
        return sections
    }
}

private extension SessionRows {
    var visibleRows: [SessionRow] {
        filtered.isEmpty ? all : filtered
    }
}
