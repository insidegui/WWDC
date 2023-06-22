//
//  SearchCoordinator.swift
//  WWDC
//
//  Created by Guilherme Rambo on 25/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
import ConfCore
import RealmSwift
import OSLog

final class SearchCoordinator: Logging {

    let storage: Storage

    static let log = makeLogger()

    /// The desired state of the filters upon configuration
    private var restorationFiltersState: WWDCFiltersState?

    fileprivate var scheduleSearchController: SearchFiltersViewController
    @Published var scheduleFilterPredicate: NSPredicate?

    fileprivate var videosSearchController: SearchFiltersViewController
    @Published var videosFilterPredicate: NSPredicate?

    init(
        _ storage: Storage,
        scheduleSearchController: SearchFiltersViewController,
        videosSearchController: SearchFiltersViewController,
        restorationFiltersState: String? = nil
    ) {
        self.storage = storage
        self.scheduleSearchController = scheduleSearchController
        self.videosSearchController = videosSearchController
        self.restorationFiltersState = restorationFiltersState
            .flatMap { $0.data(using: .utf8) }
            .flatMap { try? JSONDecoder().decode(WWDCFiltersState.self, from: $0) }

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(activateSearchField),
                                               name: .MainWindowWantsToSelectSearchField,
                                               object: nil)
    }

    func apply(_ state: WWDCFiltersState) {
        restorationFiltersState = state
        configureFilters()
    }

    func configureFilters() {
        // Schedule Filters Configuration

        var scheduleTextualFilter = TextualFilter(identifier: FilterIdentifier.text, value: nil)

        let eventOptions = storage.allSessionTypes.map { FilterOption(title: $0, value: $0) }
        var scheduleEventFilter = MultipleChoiceFilter(identifier: FilterIdentifier.event,
                                                       isSubquery: true,
                                                       collectionKey: "instances",
                                                       modelKey: "rawSessionType",
                                                       options: eventOptions,
                                                       selectedOptions: [],
                                                       emptyTitle: "All Events")

        let focusOptions = storage.allFocuses.map { FilterOption(title: $0.name, value: $0.name) }
        var scheduleFocusFilter = MultipleChoiceFilter(identifier: FilterIdentifier.focus,
                                                       isSubquery: true,
                                                       collectionKey: "focuses",
                                                       modelKey: "name",
                                                       options: focusOptions,
                                                       selectedOptions: [],
                                                       emptyTitle: "All Platforms")

        let trackOptions = storage.allTracks.map { FilterOption(title: $0.name, value: $0.name) }
        var scheduleTrackFilter = MultipleChoiceFilter(identifier: FilterIdentifier.track,
                                                       isSubquery: false,
                                                       collectionKey: "",
                                                       modelKey: "trackName",
                                                       options: trackOptions,
                                                       selectedOptions: [],
                                                       emptyTitle: "All Topics")

        let favoritePredicate = NSPredicate(format: "SUBQUERY(favorites, $favorite, $favorite.isDeleted == false).@count > 0")
        var scheduleFavoriteFilter = ToggleFilter(identifier: FilterIdentifier.isFavorite,
                                                  isOn: false,
                                                  defaultValue: false,
                                                  customPredicate: favoritePredicate)

        let downloadedPredicate = NSPredicate(format: "isDownloaded == true")
        var scheduleDownloadedFilter = ToggleFilter(identifier: FilterIdentifier.isDownloaded,
                                                    isOn: false,
                                                    defaultValue: false,
                                                    customPredicate: downloadedPredicate)

        let smallPositionPred = NSPredicate(format: "SUBQUERY(progresses, $progress, $progress.relativePosition < \(Constants.watchedVideoRelativePosition)).@count > 0")
        let noPositionPred = NSPredicate(format: "progresses.@count == 0")

        let unwatchedPredicate = NSCompoundPredicate(orPredicateWithSubpredicates: [smallPositionPred, noPositionPred])

        var scheduleUnwatchedFilter = ToggleFilter(identifier: FilterIdentifier.isUnwatched,
                                                   isOn: false,
                                                   defaultValue: false,
                                                   customPredicate: unwatchedPredicate)

        let bookmarksPredicate = NSPredicate(format: "SUBQUERY(bookmarks, $bookmark, $bookmark.isDeleted == false).@count > 0")

        var scheduleBookmarksFilter = ToggleFilter(identifier: FilterIdentifier.hasBookmarks,
                                                     isOn: false,
                                                     defaultValue: false,
                                                     customPredicate: bookmarksPredicate)

        // Schedule Filtering State Restoration

        let savedScheduleFiltersState = restorationFiltersState?.scheduleTab

        scheduleTextualFilter.value = savedScheduleFiltersState?.text?.value
        scheduleEventFilter.selectedOptions = savedScheduleFiltersState?.event?.selectedOptions ?? []
        scheduleFocusFilter.selectedOptions = savedScheduleFiltersState?.focus?.selectedOptions ?? []
        scheduleTrackFilter.selectedOptions = savedScheduleFiltersState?.track?.selectedOptions ?? []
        scheduleFavoriteFilter.isOn = savedScheduleFiltersState?.isFavorite?.isOn ?? false
        scheduleDownloadedFilter.isOn = savedScheduleFiltersState?.isDownloaded?.isOn ?? false
        scheduleUnwatchedFilter.isOn = savedScheduleFiltersState?.isUnwatched?.isOn ?? false
        scheduleBookmarksFilter.isOn = savedScheduleFiltersState?.hasBookmarks?.isOn ?? false

        let scheduleSearchFilters: [FilterType] = [scheduleTextualFilter,
                                                   scheduleEventFilter,
                                                   scheduleFocusFilter,
                                                   scheduleTrackFilter,
                                                   scheduleFavoriteFilter,
                                                   scheduleDownloadedFilter,
                                                   scheduleUnwatchedFilter,
                                                   scheduleBookmarksFilter]

        if !scheduleSearchController.filters.isIdentical(to: scheduleSearchFilters) {
            scheduleSearchController.filters = scheduleSearchFilters
        }

        // Videos Filter Configuration

        let savedVideosFiltersState = restorationFiltersState?.videosTab

        var videosTextualFilter = scheduleTextualFilter

        var videosEventOptions = storage.eventsForFiltering
            .map { FilterOption(title: $0.name, value: $0.identifier) }
            // Ensure WWDC events are always on top of non-WWDC events.
            .sorted(by: { $0.isWWDCEvent && !$1.isWWDCEvent })

        /// Add a separator between WWDC and non-WWDC events.
        if let lastWWDCIndex = videosEventOptions.lastIndex(where: { $0.isWWDCEvent }), lastWWDCIndex != videosEventOptions.endIndex {
            videosEventOptions.insert(.separator, at: lastWWDCIndex + 1)
        }
        
        var videosEventFilter = MultipleChoiceFilter(identifier: FilterIdentifier.event,
                                                     isSubquery: false,
                                                     collectionKey: "",
                                                     modelKey: "eventIdentifier",
                                                     options: videosEventOptions,
                                                     selectedOptions: [],
                                                     emptyTitle: "All Events")

        var videosFocusFilter = scheduleFocusFilter
        var videosTrackFilter = scheduleTrackFilter
        var videosFavoriteFilter = scheduleFavoriteFilter
        var videosDownloadedFilter = scheduleDownloadedFilter
        var videosUnwatchedFilter = scheduleUnwatchedFilter
        var videosBookmarksFilter = scheduleBookmarksFilter

        // Videos Filtering State Restoration

        videosTextualFilter.value = savedVideosFiltersState?.text?.value
        videosEventFilter.selectedOptions = savedVideosFiltersState?.event?.selectedOptions ?? []
        videosFocusFilter.selectedOptions = savedVideosFiltersState?.focus?.selectedOptions ?? []
        videosTrackFilter.selectedOptions = savedVideosFiltersState?.track?.selectedOptions ?? []
        videosFavoriteFilter.isOn = savedVideosFiltersState?.isFavorite?.isOn ?? false
        videosDownloadedFilter.isOn = savedVideosFiltersState?.isDownloaded?.isOn ?? false
        videosUnwatchedFilter.isOn = savedVideosFiltersState?.isUnwatched?.isOn ?? false
        videosBookmarksFilter.isOn = savedVideosFiltersState?.hasBookmarks?.isOn ?? false

        let videosSearchFilters: [FilterType] = [videosTextualFilter,
                                                 videosEventFilter,
                                                 videosFocusFilter,
                                                 videosTrackFilter,
                                                 videosFavoriteFilter,
                                                 videosDownloadedFilter,
                                                 videosUnwatchedFilter,
                                                 videosBookmarksFilter]

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
        }

        // set delegates
        scheduleSearchController.delegate = self
        videosSearchController.delegate = self

        updateSearchResults(for: .schedule, with: scheduleSearchController.filters)
        updateSearchResults(for: .videos, with: videosSearchController.filters)
    }

    enum Thing {
        case schedule, videos
    }

    func newFilterPredicate(for controller: Thing, filters: [FilterType]) -> NSPredicate? {
        guard filters.contains(where: { !$0.isEmpty }) else {
            return nil
        }

        var subpredicates = filters.compactMap { $0.predicate }

        if controller == .schedule {
            subpredicates.append(NSPredicate(format: "ANY event.isCurrent == true"))
            subpredicates.append(NSPredicate(format: "instances.@count > 0"))
        } else if controller == .videos {
            subpredicates.append(Session.videoPredicate)
        }

        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: subpredicates)

        log.debug(
            """
            \(String(describing: controller).capitalized, privacy: .public) \
            list filtering with predicate for \(String(describing: predicate), privacy: .public)
            """
        )

        return predicate
    }

    fileprivate func updateSearchResults(for controller: Thing, with filters: [FilterType]) {
        let predicate = newFilterPredicate(for: controller, filters: filters)

        switch controller {
        case .schedule:
            scheduleFilterPredicate = predicate
        case .videos:
            videosFilterPredicate = predicate
        }
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
            updateSearchResults(for: .schedule, with: filters)
        } else {
            updateSearchResults(for: .videos, with: filters)
        }
    }

}

private extension FilterOption {
    var isWWDCEvent: Bool { title.uppercased().hasPrefix("WWDC") }
}
