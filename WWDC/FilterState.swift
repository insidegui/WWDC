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
            focus: filters.find(MultipleChoiceFilter.self, byID: .focus)?.state,
            event: filters.find(MultipleChoiceFilter.self, byID: .event)?.state,
            track: filters.find(MultipleChoiceFilter.self, byID: .track)?.state,
            isDownloaded: filters.find(ToggleFilter.self, byID: .isDownloaded)?.state,
            isFavorite: filters.find(ToggleFilter.self, byID: .isFavorite)?.state,
            hasBookmarks: filters.find(ToggleFilter.self, byID: .hasBookmarks)?.state,
            isUnwatched: filters.find(ToggleFilter.self, byID: .isUnwatched)?.state,
            text: filters.find(TextualFilter.self, byID: .text)?.state
        )
    }
}

extension WWDCFiltersState {
    var base64Encoded: String? {
        guard let data = try? JSONEncoder().encode(self) else { return nil }
        return data.base64EncodedString()
    }

    init?(base64Encoded: String) {
        guard let data = Data(base64Encoded: Data(base64Encoded.utf8)) else { return nil }
        guard let decoded = try? JSONDecoder().decode(Self.self, from: data) else { return nil }
        self = decoded
    }
}
