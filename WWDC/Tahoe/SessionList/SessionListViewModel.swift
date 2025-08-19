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
        let model: SessionItemViewModel
        let indexOfAllSessions: Int // section+items

        init(model: SessionViewModel, index indexOfAllSessions: Int) {
            id = model.sessionIdentifier
            self.model = .init(session: model)
            self.indexOfAllSessions = indexOfAllSessions
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
    @ObservationIgnored var initialSelection: SessionIdentifiable?
    @ObservationIgnored let searchCoordinator: GlobalSearchCoordinator

    @ObservationIgnored private var rowsObserver: AnyCancellable?

    var sections: [SessionListSection] = []
    /// for detail view
    var selectedSession: SessionListSection.Session? {
        didSet {
            syncSelectedSession()
        }
    }
    /// for auto scroll
    var focusedSession: SessionListSection.Session?

    /// for list view
    var selectedSessions: Set<SessionListSection.Session> = [] {
        willSet {
            updateSelectedSession(with: newValue)
        }
    }

    @ObservationIgnored @Published var isReady = false

    init(
        searchCoordinator: GlobalSearchCoordinator,
        rowProvider: SessionRowProvider,
        initialSelection: SessionIdentifiable?
    ) {
        self.rowProvider = rowProvider
        self.initialSelection = initialSelection
        self.searchCoordinator = searchCoordinator
    }

    func prepareForDisplay() {
        updateSections(rowProvider.rows?.visibleRows.grouped() ?? [])
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
        isReady = true
        if selectedSessions.isEmpty, let selection = newSections.flatMap(\.sessions)
            .first(where: { $0.id == initialSelection?.sessionIdentifier })
        {
            selectedSessions.insert(selection)
            focusedSession = selection
            initialSelection = nil
        }
        if selectedSessions.isEmpty, let firstSession = newSections.first?.sessions.first {
            selectedSessions.insert(firstSession)
        }
        syncSelectedSession()
    }

    private func syncSelectedSession() {
        if #available(macOS 26.0, *) {
            DispatchQueue.main.async {
                self.coordinator?.detailViewModel.session = self.selectedSession?.model.session
            }
        }
    }

    private func updateSelectedSession(with newValue: Set<SessionListSection.Session>) {
        let difference = newValue.symmetricDifference(selectedSessions)
        guard let lastChange = difference.sorted(by: { $0.indexOfAllSessions < $1.indexOfAllSessions }).last else {
            return
        }
        if selectedSessions.contains(lastChange) {
            // removed
            if lastChange.id == selectedSession?.id {
                // removed the session current showing
                // select last in the section row
                selectedSession = newValue.sorted(by: { $0.indexOfAllSessions < $1.indexOfAllSessions }).last
            } else {
                // no need to change what's showing in detail
            }
        } else {
            // newly inserted
            selectedSession = lastChange
        }
    }
}

// MARK: - Selection

extension SessionListViewModel {
    private func targetSession(for identifier: String) -> SessionListSection.Session? {
        sections.flatMap(\.sessions).first(where: { $0.id == identifier })
    }

    func canDisplay(session: SessionIdentifiable) -> Bool {
        targetSession(for: session.sessionIdentifier) != nil
    }

    func select(session: SessionIdentifiable, removingFiltersIfNeeded: Bool) {
        guard let target = targetSession(for: session.sessionIdentifier) else {
            // not yet loaded
            initialSelection = session
            return
        }
        selectedSessions = [target]
        focusedSession = target
        if removingFiltersIfNeeded {
            searchCoordinator.resetAction.send()
        }
    }
}

private extension Array where Element == SessionRow {
    func grouped() -> [SessionListSection] {
        var sections = [SessionListSection]()
        var currentSection: SessionListSection?
        var currentSessionIndex = 0

        for row in self {
            switch row.kind {
            case let .sectionHeader(title, symbol):
                currentSection.flatMap { sections.append($0) }
                currentSection = .init(title: title, systemSymbol: symbol, sessions: [])
            case let .session(viewModel):
                currentSection?.sessions.append(.init(model: viewModel, index: currentSessionIndex))
                currentSessionIndex += 1
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
