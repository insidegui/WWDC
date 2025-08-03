//
//  NewGlobalSearchCoordinator.swift
//  WWDC
//
//  Created by luca on 01.08.2025.
//  Copyright © 2025 Guilherme Rambo. All rights reserved.
//

import AppKit
import Combine
import ConfCore
import OSLog
import RealmSwift

struct GlobalSearchTabState {
    let additionalPredicates: [NSPredicate]
    private(set) var filterPredicate: FilterPredicate {
        willSet {
            NewGlobalSearchCoordinator.log.debug("New predicate: \(newValue.predicate?.description ?? "nil", privacy: .public)")
        }
    }

    var effectiveFilters: [FilterType] = []
    var currentPredicate: NSPredicate? {
        let filters = effectiveFilters
        guard filters.contains(where: { !$0.isEmpty }) || !additionalPredicates.isEmpty else {
            return nil
        }
        let subpredicates = filters.compactMap { $0.predicate } + additionalPredicates
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: subpredicates)
        return predicate
    }

    mutating func updatePredicate(_ reason: FilterChangeReason) {
        filterPredicate = .init(predicate: currentPredicate, changeReason: reason)
    }
}

@Observable
final class NewGlobalSearchCoordinator: Logging {
    @ObservationIgnored private var cancellables: Set<AnyCancellable> = []

    static let log = makeLogger()

    /// The desired state of the filters upon configuration
    @ObservationIgnored private var restorationFiltersState: WWDCFiltersState?

    // view action caller, to avoid two way bindings
    let resetAction = PassthroughSubject<Void, Never>()
    var scheduleState = GlobalSearchTabState(
        additionalPredicates: [
            NSPredicate(format: "ANY session.event.isCurrent == true"),
            NSPredicate(format: "session.instances.@count > 0")
        ],
        filterPredicate: .init(predicate: nil, changeReason: .initialValue)
    ) {
        didSet {
            if scheduleState.filterPredicate != oldValue.filterPredicate {
                scheduleFilterPredicate = scheduleState.filterPredicate
            }
        }
    }

    var videosState = GlobalSearchTabState(
        additionalPredicates: [Session.videoPredicate],
        filterPredicate: .init(predicate: nil, changeReason: .initialValue)
    ) {
        didSet {
            if videosState.filterPredicate != oldValue.filterPredicate {
                videosFilterPredicate = videosState.filterPredicate
            }
        }
    }

    // Temporary bridge
    @ObservationIgnored @Published var scheduleFilterPredicate: FilterPredicate = .init(predicate: nil, changeReason: .initialValue)
    @ObservationIgnored @Published var videosFilterPredicate: FilterPredicate = .init(predicate: nil, changeReason: .initialValue)

    init(
        _ storage: Storage,
        restorationFiltersState: String? = nil
    ) {
        self.restorationFiltersState = restorationFiltersState
            .flatMap { $0.data(using: .utf8) }
            .flatMap { try? JSONDecoder().decode(WWDCFiltersState.self, from: $0) }

        NotificationCenter.default.publisher(for: .MainWindowWantsToSelectSearchField)
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.activateSearchField()
                }
            }
            .store(in: &cancellables)

        Publishers.CombineLatest4(
            storage.eventsForFiltering,
            storage.focuses,
            storage.tracks,
            storage.allSessionTypes
        )
        .replaceErrorWithEmpty()
        .sink { events, focuses, tracks, sessionTypes in
            self.configureFilters(
                events: events.toArray(),
                focuses: focuses.toArray(),
                tracks: tracks.toArray(),
                sessionTypes: sessionTypes
            )
        }
        .store(in: &cancellables)
    }

    /// Updates the selected filter options with the ones in the provided state
    /// Useful for programmatically changing the selected filters
    func apply(_ state: WWDCFiltersState) {
        if var videosFilters = IntermediateFiltersStructure.from(existingFilters: videosState.effectiveFilters) {
            videosFilters.apply(state.videosTab)
            videosState.effectiveFilters = videosFilters.all
            videosState.updatePredicate(.userInput)
        }

        if var scheduleFilters = IntermediateFiltersStructure.from(existingFilters: scheduleState.effectiveFilters) {
            scheduleFilters.apply(state.scheduleTab)
            scheduleState.effectiveFilters = scheduleFilters.all
            scheduleState.updatePredicate(.userInput)
        }
    }

    private func configureFilters(events: [Event], focuses: [Focus], tracks: [Track], sessionTypes: [String]) {
        // Schedule Filters Configuration

        var videoFilters = makeVideoFilters(events: events, focuses: focuses, tracks: tracks)
        if let currentControllerState = IntermediateFiltersStructure.from(existingFilters: videosState.effectiveFilters) {
            videoFilters.apply(currentControllerState)
        } else {
            videoFilters.apply(restorationFiltersState?.videosTab)
        }
        videosState.effectiveFilters = videoFilters.all
        videosState.updatePredicate(.configurationChange)

        var scheduleFilters = makeScheduleFilters(sessionTypes: sessionTypes, focuses: focuses, tracks: tracks)
        if let currentControllerState = IntermediateFiltersStructure.from(existingFilters: scheduleState.effectiveFilters) {
            scheduleFilters.apply(currentControllerState)
        } else {
            scheduleFilters.apply(restorationFiltersState?.scheduleTab)
        }
        scheduleState.effectiveFilters = scheduleFilters.all
        scheduleState.updatePredicate(.configurationChange)

        restorationFiltersState = nil
    }

    func makeVideoFilters(events: [Event], focuses: [Focus], tracks: [Track]) -> IntermediateFiltersStructure {
        let eventOptionsByType = events
            .map { FilterOption(title: $0.name, value: $0.identifier) }
            .grouped(by: \.isWWDCEvent)

        // Add a separator between WWDC and non-WWDC events.
        let eventOptions = eventOptionsByType[true, default: []] + [.separator] + eventOptionsByType[false, default: []]

        let eventFilter = MultipleChoiceFilter(
            id: .event,
            modelKey: "eventIdentifier",
            options: eventOptions,
            emptyTitle: "All Content"
        )
        let textualFilter = TextualFilter(identifier: .text, value: nil) { value in
            let modelKeys = ["title"]

            guard let value = value else { return nil }
            guard value.count >= 2 else { return nil }

            if Int(value) != nil {
                return NSPredicate(format: "%K CONTAINS[cd] %@", #keyPath(Session.number), value)
            }

            var subpredicates = modelKeys.map { key -> NSPredicate in
                return NSPredicate(format: "\(key) CONTAINS[cd] %@", value)
            }

            let keywords = NSPredicate(format: "SUBQUERY(instances, $instances, ANY $instances.keywords.name CONTAINS[cd] %@).@count > 0", value)
            subpredicates.append(keywords)

            if Preferences.shared.searchInBookmarks {
                let bookmarks = NSPredicate(format: "ANY bookmarks.body CONTAINS[cd] %@", value)
                subpredicates.append(bookmarks)
            }

            if Preferences.shared.searchInTranscripts {
                let transcripts = NSPredicate(format: "transcriptText CONTAINS[cd] %@", value)
                subpredicates.append(transcripts)
            }

            return NSCompoundPredicate(orPredicateWithSubpredicates: subpredicates)
        }

        return makeFilters(eventFilter: eventFilter, textualFilter: textualFilter, focuses: focuses, tracks: tracks)
    }

    func makeScheduleFilters(sessionTypes: [String], focuses: [Focus], tracks: [Track]) -> IntermediateFiltersStructure {
        // Schedule Filters Configuration
        let eventOptions = sessionTypes.map { FilterOption(title: $0, value: $0) }
        let eventFilter = MultipleChoiceFilter(
            id: .event,
            modelKey: "rawSessionType",
            collectionKey: "session.instances",
            options: eventOptions,
            emptyTitle: "All Content"
        )
        let textualFilter = TextualFilter(identifier: .text, value: nil) { value in
            let modelKeys = ["title"]

            guard let value = value else { return nil }
            guard value.count >= 2 else { return nil }

            if Int(value) != nil {
                return NSPredicate(format: "%K CONTAINS[cd] %@", #keyPath(SessionInstance.session.number), value)
            }

            var subpredicates = modelKeys.map { key -> NSPredicate in
                return NSPredicate(format: "session.\(key) CONTAINS[cd] %@", value)
            }

            let keywords = NSPredicate(format: "ANY keywords.name CONTAINS[cd] %@", value)
            subpredicates.append(keywords)

            if Preferences.shared.searchInBookmarks {
                let bookmarks = NSPredicate(format: "ANY session.bookmarks.body CONTAINS[cd] %@", value)
                subpredicates.append(bookmarks)
            }

            if Preferences.shared.searchInTranscripts {
                let transcripts = NSPredicate(format: "session.transcriptText CONTAINS[cd] %@", value)
                subpredicates.append(transcripts)
            }

            return NSCompoundPredicate(orPredicateWithSubpredicates: subpredicates)
        }

        return makeFilters(keyPathPrefix: "session.", eventFilter: eventFilter, textualFilter: textualFilter, focuses: focuses, tracks: tracks)
    }

    func makeFilters(keyPathPrefix: String = "", eventFilter: MultipleChoiceFilter, textualFilter: TextualFilter, focuses: [Focus], tracks: [Track]) -> IntermediateFiltersStructure {
        let focusOptions = focuses.map { FilterOption(title: $0.name, value: $0.name) }
        let focusFilter = MultipleChoiceFilter(
            id: .focus,
            modelKey: "name",
            collectionKey: "\(keyPathPrefix)focuses",
            options: focusOptions,
            emptyTitle: "All Platforms"
        )

        let trackOptions = tracks.map { FilterOption(title: $0.name, value: $0.name) }
        let trackFilter = MultipleChoiceFilter(
            id: .track,
            modelKey: "\(keyPathPrefix)trackName",
            options: trackOptions,
            emptyTitle: "All Topics"
        )

        let favoriteFilter = OptionalToggleFilter(
            id: .isFavorite,
            onPredicate: NSPredicate(format: "SUBQUERY(\(keyPathPrefix)favorites, $favorite, $favorite.isDeleted == false).@count > 0"),
            offPredicate: NSPredicate(format: "SUBQUERY(\(keyPathPrefix)favorites, $favorite, $favorite.isDeleted == false).@count == 0")
        )

        let downloadedFilter = OptionalToggleFilter(
            id: .isDownloaded,
            onPredicate: NSPredicate(format: "\(keyPathPrefix)isDownloaded == true"),
            offPredicate: NSPredicate(format: "\(keyPathPrefix)isDownloaded == false")
        )

        let smallPositionPred = NSPredicate(format: "SUBQUERY(\(keyPathPrefix)progresses, $progress, $progress.relativePosition < \(Constants.watchedVideoRelativePosition)).@count > 0")
        let noPositionPred = NSPredicate(format: "\(keyPathPrefix)progresses.@count == 0")
        let unwatchedFilter = OptionalToggleFilter(
            id: .isUnwatched,
            onPredicate: NSCompoundPredicate(andPredicateWithSubpredicates: [
                NSCompoundPredicate(notPredicateWithSubpredicate: smallPositionPred),
                NSCompoundPredicate(notPredicateWithSubpredicate: noPositionPred)
            ]),
            offPredicate: NSCompoundPredicate(orPredicateWithSubpredicates: [smallPositionPred, noPositionPred])
        )

        let bookmarksFilter = OptionalToggleFilter(
            id: .hasBookmarks,
            onPredicate: NSPredicate(format: "SUBQUERY(\(keyPathPrefix)bookmarks, $bookmark, $bookmark.isDeleted == false).@count > 0"),
            offPredicate: NSPredicate(format: "SUBQUERY(\(keyPathPrefix)bookmarks, $bookmark, $bookmark.isDeleted == false).@count == 0")
        )

        return IntermediateFiltersStructure(
            textual: textualFilter,
            event: eventFilter,
            platform: focusFilter,
            track: trackFilter,
            isFavorite: favoriteFilter,
            isDownloaded: downloadedFilter,
            isUnwatched: unwatchedFilter,
            hasBookmarks: bookmarksFilter
        )
    }

    @MainActor
    fileprivate func activateSearchField() {
        if
            let window = (NSApp.delegate as? AppDelegate)?.coordinator?.windowController.window,
            let searchItem = window.toolbar?.items.first(where: { $0.itemIdentifier == .searchItem }) as? NSSearchToolbarItem
        {
            window.makeFirstResponder(searchItem.searchField)
        }
    }

    private var uiState: WWDCFiltersState {
        WWDCFiltersState(
            scheduleTab: WWDCFiltersState.Tab(filters: scheduleState.effectiveFilters),
            videosTab: WWDCFiltersState.Tab(filters: videosState.effectiveFilters)
        )
    }

    func restorationSnapshot() -> String? {
        (try? JSONEncoder().encode(uiState))
            .flatMap { String(bytes: $0, encoding: .utf8) }
    }
}

private extension FilterOption {
    var isWWDCEvent: Bool { title.uppercased().hasPrefix("WWDC") }
}
