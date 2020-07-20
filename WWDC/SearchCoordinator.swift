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
import os.log

enum FilterIdentifier: String {
    case text
    case event
    case focus
    case track
    case isFavorite
    case isDownloaded
    case isUnwatched
    case hasBookmarks
}

final class SearchCoordinator {

    let storage: Storage

    let scheduleController: SessionsTableViewController
    let videosController: SessionsTableViewController

    private let log = OSLog(subsystem: "WWDC", category: "SearchCoordinator")

    /// The desired state of the filters upon configuration
    private let restorationFiltersState: WWDCFiltersState?

    fileprivate var scheduleSearchController: SearchFiltersViewController {
        return scheduleController.searchController
    }

    fileprivate var videosSearchController: SearchFiltersViewController {
        return videosController.searchController
    }

    init(_ storage: Storage,
         sessionsController: SessionsTableViewController,
         videosController: SessionsTableViewController,
         restorationFiltersState: String? = nil) {
        self.storage = storage
        scheduleController = sessionsController
        self.videosController = videosController
        self.restorationFiltersState = restorationFiltersState
            .flatMap { $0.data(using: .utf8) }
            .flatMap { try? JSONDecoder().decode(WWDCFiltersState.self, from: $0) }

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(activateSearchField),
                                               name: .MainWindowWantsToSelectSearchField,
                                               object: nil)
    }

    func configureFilters() {

        // Schedule Filters Configuration

        var scheduleTextualFilter = TextualFilter(identifier: FilterIdentifier.text, value: nil)

        let sessionOption = FilterOption(title: "Sessions", value: "Session")
        let labOption = sessionOption.negated(with: "Labs and Others")

        let eventOptions = [sessionOption, labOption]
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
                                                       emptyTitle: "All Tracks")

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

        let videosEventOptions = storage.allEvents.map { FilterOption(title: $0.name, value: $0.identifier) }
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

        if !videosSearchController.filters.isIdentical(to: videosSearchFilters) {
            videosSearchController.filters = videosSearchFilters
        }

        // set delegates
        scheduleSearchController.delegate = self
        videosSearchController.delegate = self

        updateSearchResults(for: scheduleController, with: scheduleSearchController.filters)
        updateSearchResults(for: videosController, with: videosSearchController.filters)
    }

    func newFilterResults(for controller: SessionsTableViewController, filters: [FilterType]) -> FilterResults {
        guard filters.contains(where: { !$0.isEmpty }) else {
            return FilterResults(storage: storage, query: nil)
        }

        var subpredicates = filters.compactMap { $0.predicate }

        if controller == scheduleController {
            subpredicates.append(NSPredicate(format: "ANY event.isCurrent == true"))
            subpredicates.append(NSPredicate(format: "instances.@count > 0"))
        } else if controller == videosController {
            subpredicates.append(Session.videoPredicate)
        }

        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: subpredicates)

        os_log("%{public}@", log: log, type: .debug, String(describing: predicate))

        return FilterResults(storage: storage, query: predicate)
    }

    fileprivate func updateSearchResults(for controller: SessionsTableViewController, with filters: [FilterType]) {
        controller.setFilterResults(newFilterResults(for: controller, filters: filters), animated: true, selecting: nil)
    }

    @objc fileprivate func activateSearchField() {
        if let window = scheduleSearchController.view.window {
            window.makeFirstResponder(scheduleSearchController.searchField)
        }

        if let window = videosSearchController.view.window {
            window.makeFirstResponder(videosSearchController.searchField)
        }
    }

    func currentFiltersState() -> String? {

        let state = WWDCFiltersState(
            scheduleTab: WWDCFiltersState.Tab(filters: scheduleSearchController.filters),
            videosTab: WWDCFiltersState.Tab(filters: videosSearchController.filters)
        )

        return (try? JSONEncoder().encode(state))
            .flatMap { String(bytes: $0, encoding: .utf8) }
    }
}

extension SearchCoordinator: SearchFiltersViewControllerDelegate {

    func searchFiltersViewController(_ controller: SearchFiltersViewController, didChangeFilters filters: [FilterType]) {
        if controller == scheduleSearchController {
            updateSearchResults(for: scheduleController, with: filters)
        } else {
            updateSearchResults(for: videosController, with: filters)
        }
    }

}
