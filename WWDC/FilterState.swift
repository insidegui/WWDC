//
//  FilterState.swift
//  WWDC
//
//  Created by Allen Humphreys on 7/13/20.
//  Copyright © 2020 Guilherme Rambo. All rights reserved.
//

import Foundation

struct WWDCFiltersState: Codable {
    let scheduleTab, videosTab: WWDCFiltersState.Tab

    enum CodingKeys: String, CodingKey {
        // Key names are for backward compatibility with the old way of serializing the state
        case scheduleTab = "WWDC.MainWindowTab.schedule"
        case videosTab = "WWDC.MainWindowTab.videos"
    }
}

extension WWDCFiltersState {
    struct Tab: Codable {
        let focus, event, track: MultipleChoiceFilter.State?
        let isDownloaded, isFavorite, hasBookmarks, isUnwatched: ToggleFilter.State?
        let text: TextualFilter.State?
    }
}

extension WWDCFiltersState.Tab {
    init(filters: [FilterType]) {
        self = .init(
            focus: filters.get(MultipleChoiceFilter.self, for: .focus)?.state,
            event: filters.get(MultipleChoiceFilter.self, for: .event)?.state,
            track: filters.get(MultipleChoiceFilter.self, for: .track)?.state,
            isDownloaded: filters.get(ToggleFilter.self, for: .isDownloaded)?.state,
            isFavorite: filters.get(ToggleFilter.self, for: .isFavorite)?.state,
            hasBookmarks: filters.get(ToggleFilter.self, for: .hasBookmarks)?.state,
            isUnwatched: filters.get(ToggleFilter.self, for: .isUnwatched)?.state,
            text: filters.get(TextualFilter.self, for: .text)?.state
        )
    }
}

extension Array where Element == FilterType {
    func get<T: FilterType>(_ type: T.Type, for identifier: FilterIdentifier) -> T? {
        let result = self.first { (filter) -> Bool in
            return filter.identifier == identifier && filter is T
        }

        return result as? T
    }
}
