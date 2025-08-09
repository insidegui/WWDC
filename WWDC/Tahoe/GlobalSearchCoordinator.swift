//
//  GlobalSearchCoordinator.swift
//  WWDC
//
//  Created by luca on 06.08.2025.
//  Copyright © 2025 Guilherme Rambo. All rights reserved.
//
import AppKit
import Combine
import ConfCore
import OSLog
import RealmSwift

@Observable
class GlobalSearchCoordinator: Logging {
    @ObservationIgnored private var cancellables: Set<AnyCancellable> = []

    @ObservationIgnored static let log = makeLogger()

    /// The desired state of the filters upon configuration
    @ObservationIgnored fileprivate var restorationFiltersState: WWDCFiltersState?

    // view action caller, to avoid two way bindings
    @ObservationIgnored let resetAction = PassthroughSubject<Void, Never>()

    @ObservationIgnored fileprivate var tabState: GlobalSearchTabState

    @ObservationIgnored var effectiveFilters: [FilterType] {
        get { tabState.effectiveFilters }
        set { tabState.effectiveFilters = newValue }
    }

    var filterPredicate: FilterPredicate = .init(predicate: nil, changeReason: .initialValue)

    init(
        _ storage: Storage,
        tabState: GlobalSearchTabState,
        restorationFiltersState: String? = nil
    ) {
        self.restorationFiltersState = restorationFiltersState
            .flatMap { $0.data(using: .utf8) }
            .flatMap { try? JSONDecoder().decode(WWDCFiltersState.self, from: $0) }
        self.tabState = tabState

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
        .sink { [weak self] events, focuses, tracks, sessionTypes in
            self?.configureFilters(
                events: events.toArray(),
                focuses: focuses.toArray(),
                tracks: tracks.toArray(),
                sessionTypes: sessionTypes
            )
        }
        .store(in: &cancellables)
    }

    func updatePredicate(_ reason: FilterChangeReason) {
        tabState.updatePredicate(reason)
    }

    /// Updates the selected filter options with the ones in the provided state
    /// Useful for programmatically changing the selected filters
    func apply(for tab: WWDCFiltersState.Tab) {
        if var filters = IntermediateFiltersStructure.from(existingFilters: tabState.effectiveFilters) {
            filters.apply(tab)
            tabState.effectiveFilters = filters.all
            tabState.updatePredicate(.userInput)
        }
    }

    fileprivate func configureFilters(events: [Event], focuses: [Focus], tracks: [Track], sessionTypes: [String]) {
        restorationFiltersState = nil
        // subclass override
    }

    @MainActor
    private func activateSearchField() {
        if
            let window = (NSApp.delegate as? AppDelegate)?.coordinator?.windowController.window,
            let searchItem = window.toolbar?.items.first(where: { $0.itemIdentifier == .searchItem }) as? NSSearchToolbarItem
        {
            window.makeFirstResponder(searchItem.searchField)
        }
    }
}

// MARK: - Schedule

class ScheduleSearchCoordinator: GlobalSearchCoordinator {
    override fileprivate func configureFilters(events: [Event], focuses: [Focus], tracks: [Track], sessionTypes: [String]) {
        var filters = makeScheduleFilters(sessionTypes: sessionTypes, focuses: focuses, tracks: tracks)
        if let currentControllerState = IntermediateFiltersStructure.from(existingFilters: tabState.effectiveFilters) {
            filters.apply(currentControllerState)
        } else {
            filters.apply(restorationFiltersState?.scheduleTab)
        }
        tabState.effectiveFilters = filters.all
        tabState.updatePredicate(.configurationChange)
        super.configureFilters(events: events, focuses: focuses, tracks: tracks, sessionTypes: sessionTypes)
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
}

// MARK: - Videos

class VideosSearchCoordinator: GlobalSearchCoordinator {
    override fileprivate func configureFilters(events: [Event], focuses: [Focus], tracks: [Track], sessionTypes: [String]) {
        var filters = makeVideoFilters(events: events, focuses: focuses, tracks: tracks)
        if let currentControllerState = IntermediateFiltersStructure.from(existingFilters: tabState.effectiveFilters) {
            filters.apply(currentControllerState)
        } else {
            filters.apply(restorationFiltersState?.videosTab)
        }
        tabState.effectiveFilters = filters.all
        tabState.updatePredicate(.configurationChange)
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
}

// MARK: - Private helpers

private extension GlobalSearchCoordinator {
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
}

private extension FilterOption {
    var isWWDCEvent: Bool { title.uppercased().hasPrefix("WWDC") }
}
