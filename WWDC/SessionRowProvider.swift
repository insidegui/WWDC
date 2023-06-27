//
//  SessionRowProvider.swift
//  WWDC
//
//  Created by Allen Humphreys on 14/3/18.
//  Copyright © 2018 Guilherme Rambo. All rights reserved.
//

import Combine
import ConfCore
import RealmSwift

struct SessionRows {
    let all: [SessionRow]
    let filtered: [SessionRow]

    init(all: [SessionRow] = [], filtered: [SessionRow] = []) {
        self.all = all
        self.filtered = filtered
    }
}

protocol SessionRowProvider {
    func sessionRowIdentifierForToday() -> SessionIdentifiable?

    var rows: AnyPublisher<SessionRows, Never> { get }
}

final class VideosSessionRowProvider: SessionRowProvider, Logging {
    static let log = makeLogger()
    private var cancellables: Set<AnyCancellable> = []
    private let filterPredicate: any Publisher<NSPredicate?, Never>

    @Published var _rows: SessionRows = SessionRows()
    var rows: AnyPublisher<SessionRows, Never> { $_rows.dropFirst().eraseToAnyPublisher() }

    private var tracks: Results<Track>

    init<P: Publisher>(tracks: Results<Track>, filterPredicate: P) where P.Output == NSPredicate?, P.Failure == Never {
        self.tracks = tracks
        self.filterPredicate = filterPredicate

        let tracks = tracks.collectionChangedPublisher
            .replaceErrorWithEmpty()
            .map {
                Self.log.debug("tracks updated")
                return $0
            }
        let filterPredicate = filterPredicate
            .map {
                Self.log.debug("filter predicate updated")
                return $0
            }

        Publishers.CombineLatest(
            tracks,
            filterPredicate
        )
        .sink { [weak self] (tracks, predicate) in
            guard let self else { return }

            Self.log.debug("Received new update")
            self.tracks = tracks

            // TODO: Build all rows and filtered rows? Do we even need to know both of them? Can it just be "rows"
            let rows = filteredRows(predicate)
            self._rows = .init(all: rows, filtered: rows)
        }
        .store(in: &cancellables)
    }

    private func filteredRows(_ predicate: NSPredicate?) -> [SessionRow] {

        let rows: [SessionRow] = tracks.flatMap { track -> [SessionRow] in
            var trackSessions = track.sessions.filter(Session.videoPredicate)

            if let predicate {
                trackSessions = trackSessions.filter(predicate)
                guard !trackSessions.isEmpty else { return [] }
            }

            let titleRow = SessionRow(content: .init(title: track.name, symbolName: track.symbolName))

            let sessionRows: [SessionRow] = trackSessions.sorted(by: Session.sameTrackSort).compactMap { session in
                guard let viewModel = SessionViewModel(session: session, track: track) else { return nil }

                return SessionRow(viewModel: viewModel)
            }

            return [titleRow] + sessionRows
        }

        return rows
    }

    func sessionRowIdentifierForToday() -> SessionIdentifiable? {
        return nil
    }
}

// TODO: Consider using covariant/subclassing to make this simpler compared to protocol
final class ScheduleSessionRowProvider: SessionRowProvider {
    private var cancellables: Set<AnyCancellable> = []
    private let filterPredicate: any Publisher<NSPredicate?, Never>

    @Published var _rows: SessionRows = SessionRows()
    var rows: AnyPublisher<SessionRows, Never> { $_rows.dropFirst().eraseToAnyPublisher() }
    private var scheduleSections: Results<ScheduleSection>

    init<P: Publisher>(
        scheduleSections: Results<ScheduleSection>,
        filterPredicate: P
    ) where P.Output == NSPredicate?, P.Failure == Never {
        self.scheduleSections = scheduleSections
        self.filterPredicate = filterPredicate

        Publishers.CombineLatest(
            scheduleSections.collectionChangedPublisher.replaceErrorWithEmpty(),
            filterPredicate
        )
        .prefix(0)
        .sink { [weak self] (tracks, predicate) in
            guard let self else { return }

            self.scheduleSections = tracks

            // TODO: Build all rows and filtered rows? Do we even need to know both of them? Can it just be "rows"
            let rows = filteredRows(predicate)
            self._rows = .init(all: rows, filtered: rows)
        }
        .store(in: &cancellables)
    }

    private func filteredRows(_ predicate: NSPredicate?) -> [SessionRow] {
        // Only show the timezone on the first section header
        var shownTimeZone = false

        let rows: [SessionRow] = scheduleSections.flatMap { section -> [SessionRow] in
            let filteredInstances = instances(in: section, filteredBy: predicate).sorted(by: SessionInstance.standardSort)
            guard !filteredInstances.isEmpty else { return [] }

            let instanceRows: [SessionRow] = filteredInstances.compactMap { instance in
                guard let viewModel = SessionViewModel(session: instance.session, instance: instance, track: nil, style: .schedule) else { return nil }

                return SessionRow(viewModel: viewModel)
            }

            // Section header
            let titleRow = SessionRow(date: section.representedDate, showTimeZone: !shownTimeZone)

            shownTimeZone = true

            return [titleRow] + instanceRows
        }

        return rows
    }

    func sessionRowIdentifierForToday() -> SessionIdentifiable? {

        guard let section = scheduleSections.filter("representedDate >= %@", today()).first else { return nil }

        guard let identifier = section.instances.first?.session?.identifier else { return nil }

        return SessionIdentifier(identifier)
    }

    private func instances(in section: ScheduleSection, filteredBy predicate: NSPredicate?) -> [SessionInstance] {
//        if let included = included {
//            let sessionIdentifiers = Array(included.map { $0.identifier })
//            return Array(section.instances.filter(NSPredicate(format: "session.identifier IN %@", sessionIdentifiers)))
//        } else {
//            return Array(section.instances)
//        }

//        NSPredicate(format: "SUBQUERY(favorites, $favorite, $favorite.isDeleted == false).@count > 0")
        // TODO: The predicates for the schedule need to be updated upstream, the currently target `Session`
        // TODO: and there is no way to apply them directly to `SessionInstance`
        section.instances.filter(predicate ?? NSPredicate(value: true)).toArray()
    }
}
