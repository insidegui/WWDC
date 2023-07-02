//
//  SessionRowProvider.swift
//  WWDC
//
//  Created by Allen Humphreys on 14/3/18.
//  Copyright © 2018 Guilherme Rambo. All rights reserved.
//

import OrderedCollections
import OSLog
import Combine
import ConfCore
import RealmSwift

struct SessionRows: Equatable {
    let all: [SessionRow]
    let filtered: [SessionRow]
}

protocol SessionRowProvider {
    func sessionRowIdentifierForToday() -> SessionIdentifiable?
    func startup()

    var rows: SessionRows? { get }
    var rowsPublisher: AnyPublisher<SessionRows, Never> { get }
}

final class VideosSessionRowProvider: SessionRowProvider, Logging, Signposting {
    static let log = makeLogger()
    static let signposter = makeSignposter()

    @Published var rows: SessionRows?
    var rowsPublisher: AnyPublisher<SessionRows, Never> { $rows.dropFirst().compacted().eraseToAnyPublisher() }

    private let publisher: AnyPublisher<SessionRows?, Never>

    init<P: Publisher, PlayingSession: Publisher>(
        tracks: Results<Track>,
        filterPredicate: P,
        playingSessionIdentifier: PlayingSession
    ) where P.Output == FilterPredicate, P.Failure == Never, PlayingSession.Output == String?, PlayingSession.Failure == Never {
        // We group by tracks which is important
        // We watch for tracks to be added or removed via `collectionChangedPublisher`
        // Then within each track, we collect all the sessions sorted accordingly and watch for additions or removals via `collectionChangedPublisher`
        // All the tracks' sessions observations are collected via combineLatest() to yield an array of track-to-sorted-sessions
        // The output lets us build all possible rows up front, generally this will only emit a single value for 95% of the year
        // during WWDC they will change.
        let tracksAndSessions = tracks.collectionChangedPublisher
            .replaceErrorWithEmpty()
            .do { Self.log.debug("tracks updated") }
            .map { (tracks: Results<Track>) in
                tracks
                    .map { track in
                        track.sessions
                            .sorted(by: Session.sameTrackSortDescriptors())
                            .collectionChangedPublisher
                            .replaceErrorWithEmpty()
                            .map { (track, $0) }
                    }.combineLatest()
                    .do { Self.log.debug("Source tracks changed") }
            }
            .switchToLatest()
            .map { sortedTracks in
                Self.signposter.withIntervalSignpost("Row generation", id: Self.signposter.makeSignpostID(), "Calculate view models") {
                    Self.allViewModels(sortedTracks)
                }
            }

        // This is fairly self explanatory, it emits a value skipping the initial one and filters duplicates
        let filterPredicate = filterPredicate
            .drop { $0.changeReason == .initialValue } // wait for filters to be configured
            .removeDuplicates()
            .do { Self.log.debug("Filter predicate updated") }

        publisher = Publishers.CombineLatest3(
            tracksAndSessions.replaceErrorWithEmpty(),
            filterPredicate,
            playingSessionIdentifier
        )
        .map { (allViewModels, predicate, playingSessionIdentifier) in
            // Now we have all our sources we combine latest to get a predicate to apply to the filtered sessions
            // We mix in the currently playing session to avoid odd UX with an empty list and the details showing
            // Much like above, we go through all the tracks, now grouped by SessionRow and apply the predicate to each
            // of the track's sorted sessions and observe all of those via combineLatest()
            // This yields an array of header row to sorted and filtered sessions to session rows by identifier
            // which allows us to quickly produce a new SessionRows model with a simple dictionary lookup
            //
            // The filtered results are observed so we have live-updating filtering. For example, if you are filtered onto
            // favorites, and then unfavorite the session, the list will update and it's powered by this part here.

            let effectivePredicate: NSPredicate
            if let playingSessionIdentifier {
                effectivePredicate = NSCompoundPredicate(
                    orPredicateWithSubpredicates: [predicate.predicate ?? NSPredicate(value: true), NSPredicate(format: "identifier == %@", playingSessionIdentifier)]
                )
            } else {
                effectivePredicate = predicate.predicate ?? NSPredicate(value: true)
            }
            // Observe the filtered sessions
            // These observers emit elements in the case of a session having some property changed that is
            // affected by the query. e.g. Filtering on favorites then unfavorite a session
            return allViewModels.map { (key: SessionRow, value: (Results<Session>, OrderedDictionary<String, SessionRow>)) in
                let (allTrackSessions, sessionRows) = value
                return allTrackSessions
                    .filter(effectivePredicate)
                    .collectionChangedPublisher
                    .replaceErrorWithEmpty()
                    .map {
                        (key, ($0, sessionRows))
                    }
            }
            .combineLatest()
            .map {
                OrderedDictionary(uniqueKeysWithValues: $0)
            }
        }
        .switchToLatest()
        .map(Self.sessionRows)
        .removeDuplicates()
        .do { Self.log.debug("Updated session rows") }
        .eraseToAnyPublisher()
    }

    func startup() {
        Self.signposter.withEscapingOneShotIntervalSignpost("Row generation", "Time to first value") { endInterval in
            publisher
                .do(endInterval)
                .assign(to: &$rows)
        }
    }

    private static func allViewModels(_ trackToSortedSessions: [(Track, Results<Session>)]) -> OrderedDictionary<SessionRow, (Results<Session>, OrderedDictionary<String, SessionRow>)> {
        OrderedDictionary(
            uniqueKeysWithValues: trackToSortedSessions.compactMap { (track, trackSessions) -> (SessionRow, (Results<Session>, OrderedDictionary<String, SessionRow>))? in
                guard !trackSessions.isEmpty else { return nil }

                let titleRow = SessionRow(content: .init(title: track.name, symbolName: track.symbolName))

                let sessionRows = trackSessions.compactMap { session -> (String, SessionRow)? in
                    guard let viewModel = SessionViewModel(session: session, track: track) else { return nil }

                    return (session.identifier, SessionRow(viewModel: viewModel))
                }

                guard !sessionRows.isEmpty else { return nil }

                return (titleRow, (trackSessions, OrderedDictionary(uniqueKeysWithValues: sessionRows)))
            }
        )
    }

    private static func sessionRows(_ tracks: OrderedDictionary<SessionRow, (Results<Session>, OrderedDictionary<String, SessionRow>)>) -> SessionRows {
        let all = tracks.flatMap { (headerRow, sessions) in
            let (_, sessionRows) = sessions
            return [headerRow] + sessionRows.values
        }

        let filtered = tracks.flatMap { (headerRow, sessions) in
            let (filteredSessions, sessionRows) = sessions
            let filteredRows: [SessionRow] = filteredSessions.compactMap { outerSession in
                sessionRows[outerSession.identifier]
            }

            guard !filteredRows.isEmpty else { return [SessionRow]() }
            return [headerRow] + filteredRows
        }

        return SessionRows(all: all, filtered: filtered)
    }

    func sessionRowIdentifierForToday() -> SessionIdentifiable? {
        return nil
    }
}

final class ScheduleSessionRowProvider: SessionRowProvider, Logging, Signposting {
    static let log = makeLogger()
    static let signposter = makeSignposter()

    @Published var rows: SessionRows?
    var rowsPublisher: AnyPublisher<SessionRows, Never> { $rows.dropFirst().compacted().eraseToAnyPublisher() }

    private let publisher: AnyPublisher<SessionRows?, Never>

    init<P: Publisher, S: Publisher, PlayingSession: Publisher>(
        scheduleSections: S,
        filterPredicate: P,
        playingSessionIdentifier: PlayingSession
    ) where P.Output == FilterPredicate, P.Failure == Never, S.Output == Results<ScheduleSection>, PlayingSession.Output == String?, PlayingSession.Failure == Never {

        let sectionsAndSessions = scheduleSections
            .replaceErrorWithEmpty()
            .do { Self.log.debug("Source sections changed") }
            .map { (sections: Results<ScheduleSection>) in
                sections
                    .map { section in
                        section.instances
                            .sorted(by: SessionInstance.standardSortDescriptors())
                            .collectionChangedPublisher
                            .replaceErrorWithEmpty()
                            .map { (section, $0) }
                    }.combineLatest()
                    .do { Self.log.debug("Section instances changed") }
            }
            .switchToLatest()
            .map { sortedSections in
                Self.signposter.withIntervalSignpost("Calculate view models", id: Self.signposter.makeSignpostID()) {
                    Self.allViewModels(sortedSections)
                }
            }

        let filterPredicate = filterPredicate
            .drop { $0.changeReason == .initialValue } // wait for filters to be configured
            .removeDuplicates()
            .do { Self.log.debug("Filter predicate updated") }

        publisher = Publishers.CombineLatest3(
            sectionsAndSessions.replaceErrorWithEmpty(),
            filterPredicate,
            playingSessionIdentifier
        )
        .map { (allViewModels, predicate, playingSessionIdentifier) in
            let effectivePredicate: NSPredicate
            if let playingSessionIdentifier {
                effectivePredicate = NSCompoundPredicate(
                    orPredicateWithSubpredicates: [predicate.predicate ?? NSPredicate(value: true), NSPredicate(format: "identifier == %@", playingSessionIdentifier)]
                )
            } else {
                effectivePredicate = predicate.predicate ?? NSPredicate(value: true)
            }
            // Observe the filtered sessions
            // These observers emit elements in the case of a session having some property changed that is
            // affected by the query. e.g. Filtering on favorites then unfavorite a session
            return allViewModels.map { (key: SessionRow, value: (Results<SessionInstance>, OrderedDictionary<String, SessionRow>)) in
                let (allSectionInstances, sessionRows) = value
                return allSectionInstances
                    .filter(effectivePredicate)
                    .collectionChangedPublisher
                    .replaceErrorWithEmpty()
                    .map {
                        (key, ($0, sessionRows))
                    }
            }
            .combineLatest()
            .map {
                OrderedDictionary(uniqueKeysWithValues: $0)
            }
            .do {
                Self.log.debug("Filtered instances changed")
            }
        }
        .switchToLatest()
        .map(Self.sessionRows)
        .removeDuplicates()
        .do { Self.log.debug("Updated session rows") }
        .eraseToAnyPublisher()
    }

    func startup() {
        Self.signposter.withEscapingOneShotIntervalSignpost("Time to first value") { endInterval in
            publisher
                .do(endInterval)
                .assign(to: &$rows)
        }
    }

    private static func allViewModels(_ sections: [(ScheduleSection, Results<SessionInstance>)]) -> OrderedDictionary<SessionRow, (Results<SessionInstance>, OrderedDictionary<String, SessionRow>)> {
        OrderedDictionary(
            uniqueKeysWithValues: sections.compactMap { (section, sectionInstances) -> (SessionRow, (Results<SessionInstance>, OrderedDictionary<String, SessionRow>))? in
                guard !sectionInstances.isEmpty else { return nil }

                let titleRow = SessionRow(date: section.representedDate, showTimeZone: true)

                let sessionRows = sectionInstances.compactMap { instance -> (String, SessionRow)? in
                    guard let session = instance.session, let viewModel = SessionViewModel(session: session, instance: instance, track: nil, style: .schedule) else { return nil }

                    return (session.identifier, SessionRow(viewModel: viewModel))
                }

                guard !sessionRows.isEmpty else { return nil }

                return (titleRow, (sectionInstances, OrderedDictionary(uniqueKeysWithValues: sessionRows)))
            }
        )
    }

    private static func sessionRows(_ sections: OrderedDictionary<SessionRow, (Results<SessionInstance>, OrderedDictionary<String, SessionRow>)>) -> SessionRows {
        let all = sections.flatMap { (headerRow, sessions) in
            let (_, sessionRows) = sessions
            return [headerRow] + sessionRows.values
        }

        let filtered = sections.flatMap { (headerRow, sessions) in
            let (filteredSessions, sessionRows) = sessions
            let filteredRows: [SessionRow] = filteredSessions.compactMap { outerSession in
                sessionRows[outerSession.identifier]
            }

            guard !filteredRows.isEmpty else { return [SessionRow]() }
            return [headerRow] + filteredRows
        }

        return SessionRows(all: all, filtered: filtered)
    }

    func sessionRowIdentifierForToday() -> SessionIdentifiable? {
        guard let rows else { return nil }

        let sessionViewModelForToday = rows.filtered.lazy.compactMap { $0.sessionViewModel }.first {
            return $0.sessionInstance.startTime >= today()
        }

        guard let sessionViewModelForToday else { return nil }

        return sessionViewModelForToday
    }
}
