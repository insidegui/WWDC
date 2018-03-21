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
import SwiftyJSON

enum FilterIdentifier: String {
    case text
    case event
    case focus
    case track
    case isFavorite
    case isDownloaded
    case isUnwatched
}

final class SearchCoordinator {

    let storage: Storage

    let scheduleController: SessionsTableViewController
    let videosController: SessionsTableViewController

    /// The desired state of the filters upon configuration
    private let restorationFiltersState: JSON?

    fileprivate var scheduleSearchController: SearchFiltersViewController {
        return scheduleController.searchController
    }

    fileprivate var videosSearchController: SearchFiltersViewController {
        return videosController.searchController
    }

    init(_ storage: Storage,
         sessionsController: SessionsTableViewController,
         videosController: SessionsTableViewController,
         restorationFiltersState: JSON? = nil) {
        self.storage = storage
        scheduleController = sessionsController
        self.videosController = videosController
        self.restorationFiltersState = restorationFiltersState

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(activateSearchField),
                                               name: .MainWindowWantsToSelectSearchField,
                                               object: nil)
    }

    func configureFilters() {

        // Schedule Filters Configuration

        var scheduleTextualFilter = TextualFilter(identifier: FilterIdentifier.text.rawValue, value: nil)

        let sessionOption = FilterOption(title: "Sessions", value: "Session")
        let labOption = sessionOption.negated(with: "Labs and Others")

        let eventOptions = [sessionOption, labOption]
        var scheduleEventFilter = MultipleChoiceFilter(identifier: FilterIdentifier.event.rawValue,
                                                       isSubquery: true,
                                                       collectionKey: "instances",
                                                       modelKey: "rawSessionType",
                                                       options: eventOptions,
                                                       selectedOptions: [],
                                                       emptyTitle: "All Events")

        let focusOptions = storage.allFocuses.map { FilterOption(title: $0.name, value: $0.name) }
        var scheduleFocusFilter = MultipleChoiceFilter(identifier: FilterIdentifier.focus.rawValue,
                                                       isSubquery: true,
                                                       collectionKey: "focuses",
                                                       modelKey: "name",
                                                       options: focusOptions,
                                                       selectedOptions: [],
                                                       emptyTitle: "All Platforms")

        let trackOptions = storage.allTracks.map { FilterOption(title: $0.name, value: $0.name) }
        var scheduleTrackFilter = MultipleChoiceFilter(identifier: FilterIdentifier.track.rawValue,
                                                       isSubquery: false,
                                                       collectionKey: "",
                                                       modelKey: "trackName",
                                                       options: trackOptions,
                                                       selectedOptions: [],
                                                       emptyTitle: "All Tracks")

        let favoritePredicate = NSPredicate(format: "SUBQUERY(favorites, $favorite, $favorite.isDeleted == false).@count > 0")
        var scheduleFavoriteFilter = ToggleFilter(identifier: FilterIdentifier.isFavorite.rawValue,
                                                  isOn: false,
                                                  customPredicate: favoritePredicate)

        let downloadedPredicate = NSPredicate(format: "isDownloaded == true")
        var scheduleDownloadedFilter = ToggleFilter(identifier: FilterIdentifier.isDownloaded.rawValue,
                                                    isOn: false,
                                                    customPredicate: downloadedPredicate)

        let smallPositionPred = NSPredicate(format: "SUBQUERY(progresses, $progress, $progress.relativePosition < \(Constants.watchedVideoRelativePosition)).@count > 0")
        let noPositionPred = NSPredicate(format: "progresses.@count == 0")

        let unwatchedPredicate = NSCompoundPredicate(orPredicateWithSubpredicates: [smallPositionPred, noPositionPred])

        var scheduleUnwatchedFilter = ToggleFilter(identifier: FilterIdentifier.isUnwatched.rawValue,
                                                   isOn: false,
                                                   customPredicate: unwatchedPredicate)

        // Schedule Filtering State Restoration

        let savedScheduleFiltersState = restorationFiltersState?[MainWindowTab.schedule.stringValue()]

        scheduleTextualFilter.value = savedScheduleFiltersState?[FilterIdentifier.text.rawValue]["value"].string
        scheduleEventFilter.selectedOptions = Array(savedScheduleFiltersState?[FilterIdentifier.event.rawValue]["selectedOptions"].arrayObject) ?? []
        scheduleFocusFilter.selectedOptions = Array(savedScheduleFiltersState?[FilterIdentifier.focus.rawValue]["selectedOptions"].arrayObject) ?? []
        scheduleTrackFilter.selectedOptions = Array(savedScheduleFiltersState?[FilterIdentifier.track.rawValue]["selectedOptions"].arrayObject) ?? []
        scheduleFavoriteFilter.isOn = savedScheduleFiltersState?[FilterIdentifier.isFavorite.rawValue]["isOn"].bool ?? false
        scheduleDownloadedFilter.isOn = savedScheduleFiltersState?[FilterIdentifier.isDownloaded.rawValue]["isOn"].bool ?? false
        scheduleUnwatchedFilter.isOn = savedScheduleFiltersState?[FilterIdentifier.isUnwatched.rawValue]["isOn"].bool ?? false

        let scheduleSearchFilters: [FilterType] = [scheduleTextualFilter,
                                                   scheduleEventFilter,
                                                   scheduleFocusFilter,
                                                   scheduleTrackFilter,
                                                   scheduleFavoriteFilter,
                                                   scheduleDownloadedFilter,
                                                   scheduleUnwatchedFilter]

        if !scheduleSearchController.filters.isIdentical(to: scheduleSearchFilters) {
            scheduleSearchController.filters = scheduleSearchFilters
        }

        // Videos Filter Configuration

        let savedVideosFiltersState = restorationFiltersState?[MainWindowTab.videos.stringValue()]

        var videosTextualFilter = scheduleTextualFilter

        let videosEventOptions = storage.allEvents.map { FilterOption(title: $0.name, value: $0.identifier) }
        var videosEventFilter = MultipleChoiceFilter(identifier: FilterIdentifier.event.rawValue,
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

        // Videos Filtering State Restoration

        videosTextualFilter.value = savedVideosFiltersState?[FilterIdentifier.text.rawValue]["value"].string
        videosEventFilter.selectedOptions = Array(savedVideosFiltersState?[FilterIdentifier.event.rawValue]["selectedOptions"].arrayObject) ?? []
        videosFocusFilter.selectedOptions = Array(savedVideosFiltersState?[FilterIdentifier.focus.rawValue]["selectedOptions"].arrayObject) ?? []
        videosTrackFilter.selectedOptions = Array(savedVideosFiltersState?[FilterIdentifier.track.rawValue]["selectedOptions"].arrayObject) ?? []
        videosFavoriteFilter.isOn = savedVideosFiltersState?[FilterIdentifier.isFavorite.rawValue]["isOn"].bool ?? false
        videosDownloadedFilter.isOn = savedVideosFiltersState?[FilterIdentifier.isDownloaded.rawValue]["isOn"].bool ?? false
        videosUnwatchedFilter.isOn = savedVideosFiltersState?[FilterIdentifier.isUnwatched.rawValue]["isOn"].bool ?? false

        let videosSearchFilters: [FilterType] = [videosTextualFilter,
                                                 videosEventFilter,
                                                 videosFocusFilter,
                                                 videosTrackFilter,
                                                 videosFavoriteFilter,
                                                 videosDownloadedFilter,
                                                 videosUnwatchedFilter]

        if !videosSearchController.filters.isIdentical(to: videosSearchFilters) {
            videosSearchController.filters = videosSearchFilters
        }

        // set delegates
        scheduleSearchController.delegate = self
        videosSearchController.delegate = self
    }

    func applyScheduleFilters() {
        updateSearchResults(for: scheduleController, with: scheduleSearchController.filters)
    }

    func applyVideosFilters() {
        updateSearchResults(for: videosController, with: videosSearchController.filters)
    }

    fileprivate lazy var searchQueue: DispatchQueue = DispatchQueue(label: "Search", qos: .userInteractive)

    fileprivate func updateSearchResults(for controller: SessionsTableViewController, with filters: [FilterType]) {
        guard filters.contains(where: { !$0.isEmpty }) else {
            controller.searchResults = nil

            return
        }

        var subpredicates = filters.flatMap { $0.predicate }

        if controller == scheduleController {
            subpredicates.append(NSPredicate(format: "ANY event.isCurrent == true"))
            subpredicates.append(NSPredicate(format: "instances.@count > 0"))
        } else if controller == videosController {
            subpredicates.append(Session.videoPredicate)
        }

        var predicate = NSCompoundPredicate(andPredicateWithSubpredicates: subpredicates)

        if let appDelegate = NSApplication.shared.delegate as? AppDelegate,
            let currentlyPlayingSession = appDelegate.coordinator.currentPlayerController?.sessionViewModel.session {

            // Keep the currently playing video in the list to ensure PIP can re-select it if needed
            predicate = NSCompoundPredicate(orPredicateWithSubpredicates: [predicate, NSPredicate(format: "identifier == %@", currentlyPlayingSession.identifier)])
        }

        #if DEBUG
            print(predicate)
        #endif

        searchQueue.async { [unowned self] in
            do {
                let realm = try Realm(configuration: self.storage.realmConfig)

                let results = realm.objects(Session.self).filter(predicate)
                let keys: Set<String> = Set(results.map { $0.identifier })

                DispatchQueue.main.async {
                    let searchResults = self.storage.realm.objects(Session.self).filter("identifier IN %@", keys)
                    controller.searchResults = searchResults
                }
            } catch {
                LoggingHelper.registerError(error, info: ["when": "Searching"])
            }
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

    func currentFiltersState() -> JSON {

        var dictionary: WWDCFiltersStateDictionary = WWDCFiltersStateDictionary()

        let videosFiltersDictionary = Dictionary(filters: videosSearchController.filters)
        let scheduleFiltersDictionary = Dictionary(filters: scheduleSearchController.filters)

        dictionary[MainWindowTab.videos.stringValue()] = videosFiltersDictionary
        dictionary[MainWindowTab.schedule.stringValue()] = scheduleFiltersDictionary

        return JSON(dictionary)
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
