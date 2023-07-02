//
//  SearchCoordinator.swift
//  WWDC
//
//  Created by Guilherme Rambo on 25/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
import Combine
import ConfCore
import RealmSwift
import OSLog

final class SearchCoordinator: Logging {

    private var cancellables: Set<AnyCancellable> = []

    static let log = makeLogger()

    /// The desired state of the filters upon configuration
    private var restorationFiltersState: WWDCFiltersState?

    fileprivate let scheduleSearchController: SearchFiltersViewController
    @Published var scheduleFilterPredicate: FilterPredicate = .init(predicate: nil, changeReason: .initialValue) {
        willSet {
            log.debug(
                "Schedule new predicate: \(newValue.predicate?.description ?? "nil", privacy: .public)"
            )
        }
    }

    fileprivate let videosSearchController: SearchFiltersViewController
    @Published var videosFilterPredicate: FilterPredicate = .init(predicate: nil, changeReason: .initialValue) {
        willSet {
            log.debug("Videos new predicate: \(newValue.predicate?.description ?? "nil", privacy: .public)")
        }
    }

    init(
        _ storage: Storage,
        scheduleSearchController: SearchFiltersViewController,
        videosSearchController: SearchFiltersViewController,
        restorationFiltersState: String? = nil
    ) {
        self.scheduleSearchController = scheduleSearchController
        scheduleSearchController.additionalPredicates = [
            NSPredicate(format: "ANY session.event.isCurrent == true"),
            NSPredicate(format: "session.instances.@count > 0")
        ]
        self.videosSearchController = videosSearchController
        videosSearchController.additionalPredicates = [
            Session.videoPredicate
        ]
        scheduleSearchController.delegate = self
        videosSearchController.delegate = self
        self.restorationFiltersState = restorationFiltersState
            .flatMap { $0.data(using: .utf8) }
            .flatMap { try? JSONDecoder().decode(WWDCFiltersState.self, from: $0) }

        NotificationCenter.default.publisher(for: .MainWindowWantsToSelectSearchField).sink { [weak self] _ in
            self?.activateSearchField()
        }.store(in: &cancellables)

        Publishers.CombineLatest4(
            storage.eventsForFilteringShallowPublisher,
            storage.focusesShallowObservable,
            storage.tracksShallowObservable,
            storage.allSessionTypesShallowPublisher
        )
        .replaceErrorWithEmpty()
        .sink { (events, focuses, tracks, sessionTypes) in
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
        if var videosFilters = IntermediateFiltersStructure.from(existingFilters: videosSearchController.filters) {
            videosFilters.apply(state.videosTab)
            videosSearchController.filters = videosFilters.all
            videosFilterPredicate = .init(
                predicate: videosSearchController.currentPredicate,
                changeReason: .userInput
            )
        }

        if var scheduleFilters = IntermediateFiltersStructure.from(existingFilters: scheduleSearchController.filters) {
            scheduleFilters.apply(state.scheduleTab)
            scheduleSearchController.filters = scheduleFilters.all
            scheduleFilterPredicate = .init(
                predicate: scheduleSearchController.currentPredicate,
                changeReason: .userInput
            )
        }
    }

    private func configureFilters(events: [Event], focuses: [Focus], tracks: [Track], sessionTypes: [String]) {
        // Schedule Filters Configuration

        var videoFilters = makeVideoFilters(events: events, focuses: focuses, tracks: tracks)
        if let currentControllerState = IntermediateFiltersStructure.from(existingFilters: videosSearchController.filters) {
            videoFilters.apply(currentControllerState)
        } else {
            videoFilters.apply(restorationFiltersState?.videosTab)
        }
        videosSearchController.filters = videoFilters.all
        videosFilterPredicate = .init(predicate: videosSearchController.currentPredicate, changeReason: .configurationChange)

        var scheduleFilters = makeScheduleFilters(sessionTypes: sessionTypes, focuses: focuses, tracks: tracks)
        if let currentControllerState = IntermediateFiltersStructure.from(existingFilters: scheduleSearchController.filters) {
            scheduleFilters.apply(currentControllerState)
        } else {
            scheduleFilters.apply(restorationFiltersState?.scheduleTab)
        }
        scheduleSearchController.filters = scheduleFilters.all
        scheduleFilterPredicate = .init(predicate: scheduleSearchController.currentPredicate, changeReason: .configurationChange)

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
            emptyTitle: "All Events"
        )
        let textualFilter = TextualFilter(identifier: .text, value: nil) { value in
            let modelKeys: [String] = ["title"]

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
            emptyTitle: "All Events"
        )
        let textualFilter = TextualFilter(identifier: .text, value: nil) { value in
            let modelKeys: [String] = ["title"]

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

        let favoritePredicate = NSPredicate(format: "SUBQUERY(\(keyPathPrefix)favorites, $favorite, $favorite.isDeleted == false).@count > 0")
        let favoriteFilter = ToggleFilter(id: .isFavorite, predicate: favoritePredicate)

        let downloadedPredicate = NSPredicate(format: "\(keyPathPrefix)isDownloaded == true")
        let downloadedFilter = ToggleFilter(id: .isDownloaded, predicate: downloadedPredicate)

        let smallPositionPred = NSPredicate(format: "SUBQUERY(\(keyPathPrefix)progresses, $progress, $progress.relativePosition < \(Constants.watchedVideoRelativePosition)).@count > 0")
        let noPositionPred = NSPredicate(format: "\(keyPathPrefix)progresses.@count == 0")
        let unwatchedPredicate = NSCompoundPredicate(orPredicateWithSubpredicates: [smallPositionPred, noPositionPred])
        let unwatchedFilter = ToggleFilter(id: .isUnwatched, predicate: unwatchedPredicate)

        let bookmarksPredicate = NSPredicate(format: "SUBQUERY(\(keyPathPrefix)bookmarks, $bookmark, $bookmark.isDeleted == false).@count > 0")
        let bookmarksFilter = ToggleFilter(id: .hasBookmarks, predicate: bookmarksPredicate)

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

    fileprivate func activateSearchField() {
        if let window = scheduleSearchController.view.window {
            window.makeFirstResponder(scheduleSearchController.searchField)
        }

        if let window = videosSearchController.view.window {
            window.makeFirstResponder(videosSearchController.searchField)
        }
    }

    private var uiState: WWDCFiltersState {
        WWDCFiltersState(
            scheduleTab: WWDCFiltersState.Tab(filters: scheduleSearchController.filters),
            videosTab: WWDCFiltersState.Tab(filters: videosSearchController.filters)
        )
    }

    func restorationSnapshot() -> String? {
        (try? JSONEncoder().encode(uiState))
            .flatMap { String(bytes: $0, encoding: .utf8) }
    }
}

extension SearchCoordinator: SearchFiltersViewControllerDelegate {

    func searchFiltersViewController(_ controller: SearchFiltersViewController, didChangeFilters filters: [FilterType], context: FilterChangeReason) {
        if controller == scheduleSearchController {
            scheduleFilterPredicate = .init(predicate: scheduleSearchController.currentPredicate, changeReason: context)
        } else {
            videosFilterPredicate = .init(predicate: videosSearchController.currentPredicate, changeReason: context)
        }
    }
}

private extension FilterOption {
    var isWWDCEvent: Bool { title.uppercased().hasPrefix("WWDC") }
}

struct IntermediateFiltersStructure {
    var textual: TextualFilter
    var event: MultipleChoiceFilter
    var platform: MultipleChoiceFilter
    var track: MultipleChoiceFilter
    var isFavorite: ToggleFilter
    var isDownloaded: ToggleFilter
    var isUnwatched: ToggleFilter
    var hasBookmarks: ToggleFilter

    var all: [FilterType] {
        [
            textual,
            event,
            platform,
            track,
            isFavorite,
            isDownloaded,
            isUnwatched,
            hasBookmarks
        ]
    }

    mutating func apply(_ state: IntermediateFiltersStructure) {
        textual.value = state.textual.value
        event.selectedOptions = state.event.selectedOptions.filter { event.options.contains($0) }
        platform.selectedOptions = state.platform.selectedOptions.filter { platform.options.contains($0) }
        track.selectedOptions = state.track.selectedOptions.filter { track.options.contains($0) }
        isFavorite.isOn = state.isFavorite.isOn
        isDownloaded.isOn = state.isDownloaded.isOn
        isUnwatched.isOn = state.isUnwatched.isOn
        hasBookmarks.isOn = state.hasBookmarks.isOn
    }

    mutating func apply(_ state: WWDCFiltersState.Tab?) {
        textual.value = state?.text?.value
        event.selectedOptions = state?.event?.selectedOptions.filter { event.options.contains($0) } ?? []
        platform.selectedOptions = state?.focus?.selectedOptions.filter { platform.options.contains($0) } ?? []
        track.selectedOptions = state?.track?.selectedOptions.filter { track.options.contains($0) } ?? []
        isFavorite.isOn = state?.isFavorite?.isOn ?? false
        isDownloaded.isOn = state?.isDownloaded?.isOn ?? false
        isUnwatched.isOn = state?.isUnwatched?.isOn ?? false
        hasBookmarks.isOn = state?.hasBookmarks?.isOn ?? false
    }

    static func from(existingFilters: [FilterType]) -> IntermediateFiltersStructure? {
        let textual: TextualFilter? = existingFilters.findBy(id: .text)
        let event: MultipleChoiceFilter? = existingFilters.findBy(id: .event)
        let platform: MultipleChoiceFilter? = existingFilters.findBy(id: .focus)
        let track: MultipleChoiceFilter? = existingFilters.findBy(id: .track)
        let isFavorite: ToggleFilter? = existingFilters.findBy(id: .isFavorite)
        let isDownloaded: ToggleFilter? = existingFilters.findBy(id: .isDownloaded)
        let isUnwatched: ToggleFilter? = existingFilters.findBy(id: .isUnwatched)
        let hasBookmarks: ToggleFilter? = existingFilters.findBy(id: .hasBookmarks)
        guard let textual, let event, let platform, let track, let isFavorite, let isDownloaded, let isUnwatched, let hasBookmarks else {
            return nil
        }

        return IntermediateFiltersStructure(
            textual: textual,
            event: event,
            platform: platform,
            track: track,
            isFavorite: isFavorite,
            isDownloaded: isDownloaded,
            isUnwatched: isUnwatched,
            hasBookmarks: hasBookmarks
        )
    }
}

struct FilterPredicate: Equatable {
    var predicate: NSPredicate?
    var changeReason: FilterChangeReason
}
