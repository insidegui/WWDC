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

    mutating func apply(_ state: WWDCFiltersState.Tab?) {
        textual.value = state?.text?.value
        event.selectedOptions = state?.event?.selectedOptions ?? []
        platform.selectedOptions = state?.focus?.selectedOptions ?? []
        track.selectedOptions = state?.track?.selectedOptions ?? []
        isFavorite.isOn = state?.isFavorite?.isOn ?? false
        isDownloaded.isOn = state?.isDownloaded?.isOn ?? false
        isUnwatched.isOn = state?.isUnwatched?.isOn ?? false
        hasBookmarks.isOn = state?.hasBookmarks?.isOn ?? false
    }
}

final class SearchCoordinator: Logging {

    private var cancellables: Set<AnyCancellable> = []

    static let log = makeLogger()

    /// The desired state of the filters upon configuration
    private var restorationFiltersState: WWDCFiltersState?

    fileprivate let scheduleSearchController: SearchFiltersViewController
    @Published var scheduleFilterPredicate: NSPredicate? {
        didSet {
            log.debug(
                "Schedule new predicate: \(self.scheduleFilterPredicate?.description ?? "nil", privacy: .public)"
            )
        }
    }

    fileprivate let videosSearchController: SearchFiltersViewController
    @Published var videosFilterPredicate: NSPredicate? {
        didSet {
            log.debug("Videos new predicate: \(self.videosFilterPredicate?.description ?? "nil", privacy: .public)")
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
            // TODO: Make sure these are shallow Realm publishers
            storage.eventsForFiltering.collectionPublisher,
            storage.focusesObservable,
            storage.tracksObservable,
            storage.allSessionTypes
        )
        .replaceErrorWithEmpty()
        .sink { (events, focuses, tracks, sessionTypes) in
            // TODO: The first event should restore state, subsequent updates should not
            self.configureFilters(
                events: events.toArray(),
                focuses: focuses.toArray(),
                tracks: tracks.toArray(),
                sessionTypes: sessionTypes
            )
        }
        .store(in: &cancellables)
    }

    func apply(_ state: WWDCFiltersState) {
        restorationFiltersState = state
//        configureFilters()
    }

    private func configureFilters(events: [Event], focuses: [Focus], tracks: [Track], sessionTypes: [String]) {
        // Schedule Filters Configuration

        var videoFilters = configureVideosFilters(events: events, focuses: focuses, tracks: tracks)
        videoFilters.apply(restorationFiltersState?.videosTab)

        // TODO: We should be able to separate state restoration from updating the filtering content from Storage
        // TODO: after the API call gets incorporated into Realm. At the moment, call this again in response to
        // TODO: content update results in a potentially stale filter state being set back onto the UI :-(
        if !videosSearchController.filters.isIdentical(to: videoFilters.all) {
            videosSearchController.filters = videoFilters.all.map {
                guard let multipleChoice = $0 as? MultipleChoiceFilter else { return $0 }
                var withClearOption = multipleChoice
                withClearOption.options.append(.separator)
                withClearOption.options.append(.clear)
                return withClearOption
            }
        }

        videosFilterPredicate = videosSearchController.currentPredicate

        var scheduleFilters = configureScheduleFilters(sessionTypes: sessionTypes, focuses: focuses, tracks: tracks)
        scheduleFilters.apply(restorationFiltersState?.scheduleTab)

        if !scheduleSearchController.filters.isIdentical(to: scheduleFilters.all) {
            scheduleSearchController.filters = scheduleFilters.all
        }

        scheduleFilterPredicate = scheduleSearchController.currentPredicate
    }

    func configureVideosFilters(events: [Event], focuses: [Focus], tracks: [Track]) -> IntermediateFiltersStructure {
        var textualFilter = TextualFilter(identifier: FilterIdentifier.text, value: nil)

        var eventOptions = events
            .map { FilterOption(title: $0.name, value: $0.identifier) }
            // Ensure WWDC events are always on top of non-WWDC events.
            .sorted(by: { $0.isWWDCEvent && !$1.isWWDCEvent })
        // Add a separator between WWDC and non-WWDC events.
        if let lastWWDCIndex = eventOptions.lastIndex(where: { $0.isWWDCEvent }),
            lastWWDCIndex != eventOptions.endIndex {
            eventOptions.insert(.separator, at: lastWWDCIndex + 1)
        }

        let eventFilter = MultipleChoiceFilter(
            .event,
            modelKey: "eventIdentifier",
            options: eventOptions,
            emptyTitle: "All Events"
        )

        let focusFilter = MultipleChoiceFilter(
            .focus,
            modelKey: "name",
            collectionKey: "focuses",
            options: focuses.map { FilterOption(title: $0.name, value: $0.name) },
            emptyTitle: "All Platforms"
        )

        let trackFilter = MultipleChoiceFilter(
            .track,
            modelKey: "trackName",
            options: tracks.map { FilterOption(title: $0.name, value: $0.name) },
            emptyTitle: "All Topics"
        )

        let favoritePredicate = NSPredicate(format: "SUBQUERY(favorites, $favorite, $favorite.isDeleted == false).@count > 0")
        let favoriteFilter = ToggleFilter(.isFavorite, predicate: favoritePredicate)

        let downloadedPredicate = NSPredicate(format: "isDownloaded == true")
        let downloadedFilter = ToggleFilter(.isDownloaded, predicate: downloadedPredicate)

        let smallPositionPred = NSPredicate(format: "SUBQUERY(progresses, $progress, $progress.relativePosition < \(Constants.watchedVideoRelativePosition)).@count > 0")
        let noPositionPred = NSPredicate(format: "progresses.@count == 0")
        let unwatchedPredicate = NSCompoundPredicate(orPredicateWithSubpredicates: [smallPositionPred, noPositionPred])
        let unwatchedFilter = ToggleFilter(.isUnwatched, predicate: unwatchedPredicate)

        let bookmarksPredicate = NSPredicate(format: "SUBQUERY(bookmarks, $bookmark, $bookmark.isDeleted == false).@count > 0")
        let bookmarksFilter = ToggleFilter(.hasBookmarks, predicate: bookmarksPredicate)

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

    func configureScheduleFilters(sessionTypes: [String], focuses: [Focus], tracks: [Track]) -> IntermediateFiltersStructure {
        // Schedule Filters Configuration

        let textualFilter = TextualFilter(identifier: FilterIdentifier.text, value: nil)

        let eventOptions = sessionTypes.map { FilterOption(title: $0, value: $0) }
        let eventFilter = MultipleChoiceFilter(
            .event,
            modelKey: "rawSessionType",
            collectionKey: "session.instances",
            options: eventOptions,
            emptyTitle: "All Events"
        )

        let focusOptions = focuses.map { FilterOption(title: $0.name, value: $0.name) }
        let focusFilter = MultipleChoiceFilter(
            .focus,
            modelKey: "name",
            collectionKey: "session.focuses",
            options: focusOptions,
            emptyTitle: "All Platforms"
        )

        let trackOptions = tracks.map { FilterOption(title: $0.name, value: $0.name) }
        let trackFilter = MultipleChoiceFilter(
            .track,
            modelKey: "session.trackName",
            options: trackOptions,
            emptyTitle: "All Topics"
        )

        let favoritePredicate = NSPredicate(format: "SUBQUERY(session.favorites, $favorite, $favorite.isDeleted == false).@count > 0")
        let favoriteFilter = ToggleFilter(.isFavorite, predicate: favoritePredicate)

        let downloadedPredicate = NSPredicate(format: "session.isDownloaded == true")
        let downloadedFilter = ToggleFilter(.isDownloaded, predicate: downloadedPredicate)

        let smallPositionPred = NSPredicate(format: "SUBQUERY(session.progresses, $progress, $progress.relativePosition < \(Constants.watchedVideoRelativePosition)).@count > 0")
        let noPositionPred = NSPredicate(format: "session.progresses.@count == 0")
        let unwatchedPredicate = NSCompoundPredicate(orPredicateWithSubpredicates: [smallPositionPred, noPositionPred])
        let unwatchedFilter = ToggleFilter(.isUnwatched, predicate: unwatchedPredicate)

        let bookmarksPredicate = NSPredicate(format: "SUBQUERY(session.bookmarks, $bookmark, $bookmark.isDeleted == false).@count > 0")
        let bookmarksFilter = ToggleFilter(.hasBookmarks, predicate: bookmarksPredicate)

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

    func searchFiltersViewController(_ controller: SearchFiltersViewController, didChangeFilters filters: [FilterType]) {
        if controller == scheduleSearchController {
            scheduleFilterPredicate = scheduleSearchController.currentPredicate
        } else {
            videosFilterPredicate = videosSearchController.currentPredicate
        }
    }

}

private extension FilterOption {
    var isWWDCEvent: Bool { title.uppercased().hasPrefix("WWDC") }
}
