//
//  DataSource.swift
//  SearchClient
//
//  Created by Guilherme Rambo on 21/02/20.
//  Copyright © 2020 Guilherme Rambo. All rights reserved.
//

import Foundation
import Combine
import WWDCSearchFoundation

struct SearchResult: Hashable, Identifiable {
    let id: String
    let summary: String
    let deepLink: String

    init(result: WWDCSearchResult) {
        self.id = result.identifier
        self.summary = result.summary
        self.deepLink = result.deepLink
    }
}

final class DataSource: ObservableObject {

    @Published private(set) var results: [SearchResult] = []

    @Published var searchTerm: String = ""

    private lazy var client = WWDCSearchClient()

    private var cancellables: [Cancellable] = []

    init() {
        let searchTermBinding = $searchTerm.debounce(for: 0.5, scheduler: DispatchQueue.main).sink { [weak self] term in
            guard term.count >= 3 else { return }

            self?.client.search(using: term, with: { result in
                DispatchQueue.main.async {
                    self?.results = result.map(SearchResult.init)
                }
            })
        }

        cancellables.append(searchTermBinding)
    }

}
