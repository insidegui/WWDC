//
//  Bundle+LoadJSON.swift
//  TranscriptsTests
//
//  Created by Guilherme Rambo on 25/05/20.
//  Copyright © 2020 Guilherme Rambo. All rights reserved.
//

import Foundation

extension Bundle {
    func loadJSON<T: Decodable>(from resource: String) throws -> T {
        guard let url = self.url(forResource: resource, withExtension: "json") else {
            fatalError("Missing \(resource) from testing bundle")
        }

        let data = try Data(contentsOf: url)

        return try JSONDecoder().decode(T.self, from: data)
    }
}
