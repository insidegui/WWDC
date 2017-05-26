//
//  SearchCoordinator.swift
//  WWDC
//
//  Created by Guilherme Rambo on 25/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
import ConfCore

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
    }
    
    func configureFilters() {
        let eventOptions = storage.allEvents.map({ FilterOption(title: $0.name, value: $0.identifier) })
        let eventFilter = FilterType(isSubquery: false, collectionKey: "", modelKey: "eventIdentifier", options: eventOptions, selectedOptions: [], emptyTitle: "All Events")
        
        let focusOptions = storage.allFocuses.map({ FilterOption(title: $0.name, value: $0.name) })
        let focusFilter = FilterType(isSubquery: true, collectionKey: "focuses", modelKey: "name", options: focusOptions, selectedOptions: [], emptyTitle: "All Platforms")
        
        let trackOptions = storage.allTracks.map({ FilterOption(title: $0.name, value: $0.name) })
        let trackFilter = FilterType(isSubquery: false, collectionKey: "", modelKey: "trackName", options: trackOptions, selectedOptions: [], emptyTitle: "All Tracks")
        
        scheduleSearchController.filters = [eventFilter, focusFilter, trackFilter]
        
        // set delegates
        scheduleSearchController.delegate = self
        videosSearchController.delegate = self
    }
    
    private func isAllEmpty(_ filters: [FilterType]) -> Bool {
        return filters.reduce(true, { return $0.0 && $0.1.isEmpty })
    }
    
    fileprivate func updateScheduleSearchResults(with filters: [FilterType]) {
        guard !isAllEmpty(filters) else {
            scheduleController.searchResults = nil
            return
        }
        
        let subpredicates = filters.flatMap({ $0.predicate })
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: subpredicates)
        
        #if DEBUG
            print(predicate)
        #endif
        
        let results = storage.realm.objects(Session.self).filter(predicate)
        
        scheduleController.searchResults = results
    }
    
    fileprivate func updateVideosSearchResults(with filters: [FilterType]) {
        guard !isAllEmpty(filters) else {
            videosController.searchResults = nil
            return
        }
    }
    
}

extension SearchCoordinator: SearchFiltersViewControllerDelegate {
    
    func searchFiltersViewController(_ controller: SearchFiltersViewController, didChangeFilters filters: [FilterType]) {
        if controller == scheduleSearchController {
            updateScheduleSearchResults(with: filters)
        } else {
            updateVideosSearchResults(with: filters)
        }
    }
    
}
