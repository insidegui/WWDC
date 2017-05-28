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
    
    fileprivate var scheduleSearchController: SearchFiltersViewController {
        return scheduleController.searchController
    }
    
    fileprivate var videosSearchController: SearchFiltersViewController {
        return videosController.searchController
    }
    
    init(_ storage: Storage,
         sessionsController: SessionsTableViewController,
         videosController: SessionsTableViewController)
    {
        self.storage = storage
        self.scheduleController = sessionsController
        self.videosController = videosController
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(activateSearchField),
                                               name: .MainWindowWantsToSelectSearchField,
                                               object: nil)
    }
    
    func configureFilters() {
        let textualFilter = TextualFilter(identifier: FilterIdentifier.text.rawValue, value: nil)

        let labOption = FilterOption(title: "Labs", value: "Lab")
        let sessionOption = labOption.negated(with: "Sessions")
        
        let instanceTypeOptions = [sessionOption, labOption]
        let instanceTypeFilter = MultipleChoiceFilter(identifier: FilterIdentifier.event.rawValue,
                                               isSubquery: true,
                                               collectionKey: "instances",
                                               modelKey: "rawSessionType",
                                               options: instanceTypeOptions,
                                               selectedOptions: [],
                                               emptyTitle: "All Events")
        
        let eventOptions = storage.allEvents.map({ FilterOption(title: $0.name, value: $0.identifier) })
        let eventFilter = MultipleChoiceFilter(identifier: FilterIdentifier.event.rawValue,
                                               isSubquery: false,
                                               collectionKey: "",
                                               modelKey: "eventIdentifier",
                                               options: eventOptions,
                                               selectedOptions: [],
                                               emptyTitle: "All Events")
        
        let focusOptions = storage.allFocuses.map({ FilterOption(title: $0.name, value: $0.name) })
        let focusFilter = MultipleChoiceFilter(identifier: FilterIdentifier.focus.rawValue,
                                               isSubquery: true,
                                               collectionKey: "focuses",
                                               modelKey: "name",
                                               options: focusOptions, 
                                               selectedOptions: [],
                                               emptyTitle: "All Platforms")
        
        let trackOptions = storage.allTracks.map({ FilterOption(title: $0.name, value: $0.name) })
        let trackFilter = MultipleChoiceFilter(identifier: FilterIdentifier.track.rawValue,
                                               isSubquery: false,
                                               collectionKey: "",
                                               modelKey: "trackName",
                                               options: trackOptions,
                                               selectedOptions: [],
                                               emptyTitle: "All Tracks")
        
        let favoritePredicate = NSPredicate(format: "SUBQUERY(favorites, $favorite, $favorite.isDeleted == false).@count > 0")
        let favoriteFilter = ToggleFilter(identifier: FilterIdentifier.isFavorite.rawValue,
                                          isOn: false,
                                          customPredicate: favoritePredicate)
        
        let downloadedPredicate = NSPredicate(format: "isDownloaded == true")
        let downloadedFilter = ToggleFilter(identifier: FilterIdentifier.isDownloaded.rawValue,
                                            isOn: false,
                                            customPredicate: downloadedPredicate)
        
        let smallPositionPred = NSPredicate(format: "SUBQUERY(progresses, $progress, $progress.relativePosition < 0.9).@count > 0")
        let noPositionPred = NSPredicate(format: "progresses.@count == 0")
        
        let unwatchedPredicate = NSCompoundPredicate(orPredicateWithSubpredicates: [smallPositionPred, noPositionPred])
        
        let unwatchedFilter = ToggleFilter(identifier: FilterIdentifier.isUnwatched.rawValue,
                                           isOn: false,
                                           customPredicate: unwatchedPredicate)
        
        scheduleSearchController.filters = [
            textualFilter,
            instanceTypeFilter,
            focusFilter,
            trackFilter,
            favoriteFilter,
            downloadedFilter,
            unwatchedFilter
        ]

        videosSearchController.filters = [
            textualFilter,
            eventFilter,
            focusFilter,
            trackFilter,
            favoriteFilter,
            downloadedFilter,
            unwatchedFilter
        ]
        
        // set delegates
        scheduleSearchController.delegate = self
        videosSearchController.delegate = self
    }
    
    private func isAllEmpty(_ filters: [FilterType]) -> Bool {
        return filters.reduce(true, { return $0.0 && $0.1.isEmpty })
    }
    
    fileprivate lazy var searchQueue: DispatchQueue = DispatchQueue(label: "Search", qos: .userInteractive)
    
    fileprivate func updateSearchResults(for controller: SessionsTableViewController, with filters: [FilterType]) {
        guard !isAllEmpty(filters) else {
            controller.searchResults = nil
            return
        }
        
        var subpredicates = filters.flatMap({ $0.predicate })
        
        if controller == scheduleController {
            subpredicates.append(NSPredicate(format: "ANY event.isCurrent == true"))
        } else if controller == videosController {
            subpredicates.append(NSPredicate(format: "ANY instances.rawSessionType != 'Lab'"))
        }
        
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: subpredicates)
        
        #if DEBUG
            print(predicate)
        #endif
        
        searchQueue.async { [unowned self] in
            do {
                let realm = try Realm(configuration: self.storage.realmConfig)
                
                let results = realm.objects(Session.self).filter(predicate)
                let keys: [String] = results.map({ $0.identifier })
                
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
