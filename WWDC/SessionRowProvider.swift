//
//  SessionRowProvider.swift
//  WWDC
//
//  Created by Allen Humphreys on 14/3/18.
//  Copyright © 2018 Guilherme Rambo. All rights reserved.
//

//
//  CombineLatestMany.swift
//  CombineExt
//
//  Created by Jasdev Singh on 22/03/2020.
//  Copyright © 2020 Combine Community. All rights reserved.
//

import OrderedCollections
import OSLog

#if canImport(Combine)
import Combine

@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public extension Publisher {
    /// Projects `self` and a `Collection` of `Publisher`s onto a type-erased publisher that chains `combineLatest` calls on
    /// the inner publishers. This is a variadic overload on Combine’s variants that top out at arity three.
    ///
    /// - parameter others: A `Collection`-worth of other publishers with matching output and failure types to combine with.
    ///
    /// - returns: A type-erased publisher with value events from `self` and each of the inner publishers `combineLatest`’d
    /// together in an array.
    func combineLatest<Others: Collection>(with others: Others)
    -> AnyPublisher<[Output], Failure>
    where Others.Element: Publisher, Others.Element.Output == Output, Others.Element.Failure == Failure {
        ([self.eraseToAnyPublisher()] + others.map { $0.eraseToAnyPublisher() }).combineLatest()
    }

    /// Projects `self` and a `Collection` of `Publisher`s onto a type-erased publisher that chains `combineLatest` calls on
    /// the inner publishers. This is a variadic overload on Combine’s variants that top out at arity three.
    ///
    /// - parameter others: A `Collection`-worth of other publishers with matching output and failure types to combine with.
    ///
    /// - returns: A type-erased publisher with value events from `self` and each of the inner publishers `combineLatest`’d
    /// together in an array.
    func combineLatest<Other: Publisher>(with others: Other...)
    -> AnyPublisher<[Output], Failure>
    where Other.Output == Output, Other.Failure == Failure {
        combineLatest(with: others)
    }
}

@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public extension Collection where Element: Publisher {
    /// Projects a `Collection` of `Publisher`s onto a type-erased publisher that chains `combineLatest` calls on
    /// the inner publishers. This is a variadic overload on Combine’s variants that top out at arity three.
    ///
    /// - returns: A type-erased publisher with value events from each of the inner publishers `combineLatest`’d
    /// together in an array.
    func combineLatest() -> AnyPublisher<[Element.Output], Element.Failure> {
        var wrapped = map { $0.map { [$0] }.eraseToAnyPublisher() }
        while wrapped.count > 1 {
            wrapped = makeCombinedQuads(input: wrapped)
        }
        return wrapped.first?.eraseToAnyPublisher() ?? Empty().eraseToAnyPublisher()
    }
}

// MARK: - Private helpers
@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
/// CombineLatest an array of input publishers in four-somes.
///
/// - parameter input: An array of publishers
private func makeCombinedQuads<Output, Failure: Swift.Error>(
    input: [AnyPublisher<[Output], Failure>]
) -> [AnyPublisher<[Output], Failure>] {
    // Iterate over the array of input publishers in steps of four
    sequence(
        state: input.makeIterator(),
        next: { it in it.next().map { ($0, it.next(), it.next(), it.next()) } }
    )
    .map { quad in
        // Only one publisher
        guard let second = quad.1 else { return quad.0 }

        // Two publishers
        guard let third = quad.2 else {
            return quad.0
                .combineLatest(second)
                .map { $0.0 + $0.1 }
                .eraseToAnyPublisher()
        }

        // Three publishers
        guard let fourth = quad.3 else {
            return quad.0
                .combineLatest(second, third)
                .map { $0.0 + $0.1 + $0.2 }
                .eraseToAnyPublisher()
        }

        // Four publishers
        return quad.0
            .combineLatest(second, third, fourth)
            .map { $0.0 + $0.1 + $0.2 + $0.3 }
            .eraseToAnyPublisher()
    }
}
#endif

import Combine
import ConfCore
import RealmSwift

struct SessionRows: Equatable {
    let all: [SessionRow]
    let filtered: [SessionRow]

    init(all: [SessionRow] = [], filtered: [SessionRow] = []) {
        self.all = all
        self.filtered = filtered
    }
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
        let tracksAndSessions = tracks.collectionChangedPublisher
            .replaceErrorWithEmpty()
            .map {
                Self.log.debug("tracks updated")
                return $0
            }
            .map { (tracks: Results<Track>) in
                tracks
                    .map { track in
                        track.sessions
                            .sorted(by: Session.sameTrackSortDescriptors())
                            .collectionChangedPublisher
                            .replaceErrorWithEmpty()
                            .map { (track, $0) }
                    }.combineLatest()
                    .do {
                        Self.log.debug("Source tracks changed")
                    }
            }
            .switchToLatest()
            .map { sortedTracks in
                Self.signposter.withIntervalSignpost("Row generation", id: Self.signposter.makeSignpostID(), "Calculate view models") {
                    Self.allViewModels(sortedTracks)
                }
            }

        let filterPredicate = filterPredicate
            .drop(while: {
                switch $0.changeReason {
                case .initialValue:
                    return true
                default:
                    return false
                }
            }).removeDuplicates(by: { previous, current in
                previous.predicate == current.predicate
            }) // wait for filters to be configured
            .do {
                Self.log.debug("Filter predicate updated")
            }
        publisher = Publishers.CombineLatest3(
            tracksAndSessions.replaceErrorWithEmpty(),
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

    private static func allViewModels(_ tracks: [(Track, Results<Session>)]) -> OrderedDictionary<SessionRow, (Results<Session>, OrderedDictionary<String, SessionRow>)> {
        OrderedDictionary(
            uniqueKeysWithValues: tracks.compactMap { (track, trackSessions) -> (SessionRow, (Results<Session>, OrderedDictionary<String, SessionRow>))? in
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

// TODO: Consider using covariant/subclassing to make this simpler compared to protocol
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
            .drop(while: {
                // wait for filters to be configured
                switch $0.changeReason {
                case .initialValue:
                    return true
                default:
                    return false
                }
            }).removeDuplicates(by: { previous, current in
                previous.predicate == current.predicate
            })
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

    private static func sessionRows(_ tracks: OrderedDictionary<SessionRow, (Results<SessionInstance>, OrderedDictionary<String, SessionRow>)>) -> SessionRows {
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
//        guard let scheduleSections else { return nil }
//
//        guard let section = scheduleSections.filter("representedDate >= %@", today()).first else { return nil }
//
//        guard let identifier = section.instances.first?.session?.identifier else { return nil }
//
//        return SessionIdentifier(identifier)
    }
}
