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
//        self.storage = storage
        self.scheduleSearchController = scheduleSearchController
        self.videosSearchController = videosSearchController
        scheduleSearchController.delegate = self
        videosSearchController.delegate = self
        self.restorationFiltersState = restorationFiltersState
            .flatMap { $0.data(using: .utf8) }
            .flatMap { try? JSONDecoder().decode(WWDCFiltersState.self, from: $0) }

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(activateSearchField),
                                               name: .MainWindowWantsToSelectSearchField,
                                               object: nil)

        Publishers.CombineLatest4(
            storage.eventsForFiltering.collectionPublisher,
            storage.focusesObservable,
            storage.tracksObservable,
            storage.allSessionTypes
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

    func apply(_ state: WWDCFiltersState) {
        restorationFiltersState = state
//        configureFilters()
    }

    private func configureFilters(events: [Event], focuses: [Focus], tracks: [Track], sessionTypes: [String]) {
        // Schedule Filters Configuration

        configureVideosFilters(events: events, focuses: focuses, tracks: tracks)
        configureScheduleFilters(sessionTypes: sessionTypes, focuses: focuses, tracks: tracks)
    }

    func configureVideosFilters(events: [Event], focuses: [Focus], tracks: [Track]) {
        var textualFilter = TextualFilter(identifier: FilterIdentifier.text, value: nil)

        var eventOptions = events
            .map { FilterOption(title: $0.name, value: $0.identifier) }
        // Ensure WWDC events are always on top of non-WWDC events.
            .sorted(by: { $0.isWWDCEvent && !$1.isWWDCEvent })
        /// Add a separator between WWDC and non-WWDC events.
        if let lastWWDCIndex = eventOptions.lastIndex(where: { $0.isWWDCEvent }), lastWWDCIndex != eventOptions.endIndex {
            eventOptions.insert(.separator, at: lastWWDCIndex + 1)
        }

        var eventFilter = MultipleChoiceFilter(identifier: FilterIdentifier.event,
                                               isSubquery: false,
                                               collectionKey: "",
                                               modelKey: "eventIdentifier",
                                               options: eventOptions,
                                               selectedOptions: [],
                                               emptyTitle: "All Events")

        let focusOptions = focuses.map { FilterOption(title: $0.name, value: $0.name) }
        var focusFilter = MultipleChoiceFilter(identifier: FilterIdentifier.focus,
                                               isSubquery: true,
                                               collectionKey: "focuses",
                                               modelKey: "name",
                                               options: focusOptions,
                                               selectedOptions: [],
                                               emptyTitle: "All Platforms")

        let trackOptions = tracks.map { FilterOption(title: $0.name, value: $0.name) }
        var trackFilter = MultipleChoiceFilter(identifier: FilterIdentifier.track,
                                               isSubquery: false,
                                               collectionKey: "",
                                               modelKey: "trackName",
                                               options: trackOptions,
                                               selectedOptions: [],
                                               emptyTitle: "All Topics")

        let favoritePredicate = NSPredicate(format: "SUBQUERY(favorites, $favorite, $favorite.isDeleted == false).@count > 0")
        var favoriteFilter = ToggleFilter(identifier: FilterIdentifier.isFavorite,
                                          isOn: false,
                                          defaultValue: false,
                                          customPredicate: favoritePredicate)

        let downloadedPredicate = NSPredicate(format: "isDownloaded == true")
        var downloadedFilter = ToggleFilter(identifier: FilterIdentifier.isDownloaded,
                                            isOn: false,
                                            defaultValue: false,
                                            customPredicate: downloadedPredicate)

        let smallPositionPred = NSPredicate(format: "SUBQUERY(progresses, $progress, $progress.relativePosition < \(Constants.watchedVideoRelativePosition)).@count > 0")
        let noPositionPred = NSPredicate(format: "progresses.@count == 0")

        let unwatchedPredicate = NSCompoundPredicate(orPredicateWithSubpredicates: [smallPositionPred, noPositionPred])

        var unwatchedFilter = ToggleFilter(identifier: FilterIdentifier.isUnwatched,
                                           isOn: false,
                                           defaultValue: false,
                                           customPredicate: unwatchedPredicate)

        let bookmarksPredicate = NSPredicate(format: "SUBQUERY(bookmarks, $bookmark, $bookmark.isDeleted == false).@count > 0")

        var bookmarksFilter = ToggleFilter(identifier: .hasBookmarks,
                                           isOn: false,
                                           defaultValue: false,
                                           customPredicate: bookmarksPredicate)

        // Schedule Filtering State Restoration

        let savedScheduleFiltersState = restorationFiltersState?.scheduleTab

        textualFilter.value = savedScheduleFiltersState?.text?.value
        eventFilter.selectedOptions = savedScheduleFiltersState?.event?.selectedOptions ?? []
        focusFilter.selectedOptions = savedScheduleFiltersState?.focus?.selectedOptions ?? []
        trackFilter.selectedOptions = savedScheduleFiltersState?.track?.selectedOptions ?? []
        favoriteFilter.isOn = savedScheduleFiltersState?.isFavorite?.isOn ?? false
        downloadedFilter.isOn = savedScheduleFiltersState?.isDownloaded?.isOn ?? false
        unwatchedFilter.isOn = savedScheduleFiltersState?.isUnwatched?.isOn ?? false
        bookmarksFilter.isOn = savedScheduleFiltersState?.hasBookmarks?.isOn ?? false

        let savedVideosFiltersState = restorationFiltersState?.videosTab

        // Apply State Restoration

        textualFilter.value = savedVideosFiltersState?.text?.value
        eventFilter.selectedOptions = savedVideosFiltersState?.event?.selectedOptions ?? []
        focusFilter.selectedOptions = savedVideosFiltersState?.focus?.selectedOptions ?? []
        trackFilter.selectedOptions = savedVideosFiltersState?.track?.selectedOptions ?? []
        favoriteFilter.isOn = savedVideosFiltersState?.isFavorite?.isOn ?? false
        downloadedFilter.isOn = savedVideosFiltersState?.isDownloaded?.isOn ?? false
        unwatchedFilter.isOn = savedVideosFiltersState?.isUnwatched?.isOn ?? false
        bookmarksFilter.isOn = savedVideosFiltersState?.hasBookmarks?.isOn ?? false

        let videosSearchFilters: [FilterType] = [textualFilter,
                                                 eventFilter,
                                                 focusFilter,
                                                 trackFilter,
                                                 favoriteFilter,
                                                 downloadedFilter,
                                                 unwatchedFilter,
                                                 bookmarksFilter]

        // TODO: We should be able to separate state restoration from updating the filtering content from Storage
        // TODO: after the API call gets incorporated into Realm. At the moment, call this again in response to
        // TODO: content update results in a potentially stale filter state being set back onto the UI :-(
        if !videosSearchController.filters.isIdentical(to: videosSearchFilters) {
            videosSearchController.filters = videosSearchFilters.map {
                guard let multipleChoice = $0 as? MultipleChoiceFilter else { return $0 }
                var withClearOption = multipleChoice
                withClearOption.options.append(.separator)
                withClearOption.options.append(.clear)
                return withClearOption
            }
            videosSearchController.additionalPredicates = [
                Session.videoPredicate
            ]
        }

        videosFilterPredicate = videosSearchController.currentPredicate
    }

    func configureScheduleFilters(sessionTypes: [String], focuses: [Focus], tracks: [Track]) {
        // Schedule Filters Configuration

        var textualFilter = TextualFilter(identifier: FilterIdentifier.text, value: nil)

        let eventOptions = sessionTypes.map { FilterOption(title: $0, value: $0) }
        var eventFilter = MultipleChoiceFilter(identifier: FilterIdentifier.event,
                                               isSubquery: true,
                                               collectionKey: "session.instances",
                                               modelKey: "rawSessionType",
                                               options: eventOptions,
                                               selectedOptions: [],
                                               emptyTitle: "All Events")

        let focusOptions = focuses.map { FilterOption(title: $0.name, value: $0.name) }
        var focusFilter = MultipleChoiceFilter(identifier: FilterIdentifier.focus,
                                               isSubquery: true,
                                               collectionKey: "session.focuses",
                                               modelKey: "name",
                                               options: focusOptions,
                                               selectedOptions: [],
                                               emptyTitle: "All Platforms")

        let trackOptions = tracks.map { FilterOption(title: $0.name, value: $0.name) }
        var trackFilter = MultipleChoiceFilter(identifier: FilterIdentifier.track,
                                               isSubquery: false,
                                               collectionKey: "",
                                               modelKey: "session.trackName",
                                               options: trackOptions,
                                               selectedOptions: [],
                                               emptyTitle: "All Topics")

        let favoritePredicate = NSPredicate(format: "SUBQUERY(session.favorites, $favorite, $favorite.isDeleted == false).@count > 0")
        var favoriteFilter = ToggleFilter(
            identifier: FilterIdentifier.isFavorite,
            isOn: false,
            defaultValue: false,
            customPredicate: favoritePredicate
        )

        let downloadedPredicate = NSPredicate(format: "session.isDownloaded == true")
        var downloadedFilter = ToggleFilter(identifier: FilterIdentifier.isDownloaded,
                                            isOn: false,
                                            defaultValue: false,
                                            customPredicate: downloadedPredicate)

        let smallPositionPred = NSPredicate(format: "SUBQUERY(session.progresses, $progress, $progress.relativePosition < \(Constants.watchedVideoRelativePosition)).@count > 0")
        let noPositionPred = NSPredicate(format: "session.progresses.@count == 0")

        let unwatchedPredicate = NSCompoundPredicate(orPredicateWithSubpredicates: [smallPositionPred, noPositionPred])

        var unwatchedFilter = ToggleFilter(identifier: FilterIdentifier.isUnwatched,
                                           isOn: false,
                                           defaultValue: false,
                                           customPredicate: unwatchedPredicate)

        let bookmarksPredicate = NSPredicate(format: "SUBQUERY(session.bookmarks, $bookmark, $bookmark.isDeleted == false).@count > 0")

        var bookmarksFilter = ToggleFilter(identifier: FilterIdentifier.hasBookmarks,
                                           isOn: false,
                                           defaultValue: false,
                                           customPredicate: bookmarksPredicate)

        // Schedule Filtering State Restoration

        let savedScheduleFiltersState = restorationFiltersState?.scheduleTab

        textualFilter.value = savedScheduleFiltersState?.text?.value
        eventFilter.selectedOptions = savedScheduleFiltersState?.event?.selectedOptions ?? []
        focusFilter.selectedOptions = savedScheduleFiltersState?.focus?.selectedOptions ?? []
        trackFilter.selectedOptions = savedScheduleFiltersState?.track?.selectedOptions ?? []
        favoriteFilter.isOn = savedScheduleFiltersState?.isFavorite?.isOn ?? false
        downloadedFilter.isOn = savedScheduleFiltersState?.isDownloaded?.isOn ?? false
        unwatchedFilter.isOn = savedScheduleFiltersState?.isUnwatched?.isOn ?? false
        bookmarksFilter.isOn = savedScheduleFiltersState?.hasBookmarks?.isOn ?? false

        let scheduleSearchFilters: [FilterType] = [textualFilter,
                                                   eventFilter,
                                                   focusFilter,
                                                   trackFilter,
                                                   favoriteFilter,
                                                   downloadedFilter,
                                                   unwatchedFilter,
                                                   bookmarksFilter]

        if !scheduleSearchController.filters.isIdentical(to: scheduleSearchFilters) {
            scheduleSearchController.filters = scheduleSearchFilters
            scheduleSearchController.additionalPredicates = [
                NSPredicate(format: "ANY session.event.isCurrent == true"),
                NSPredicate(format: "session.instances.@count > 0")
            ]
        }

        scheduleFilterPredicate = scheduleSearchController.currentPredicate
    }

    @objc fileprivate func activateSearchField() {
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
