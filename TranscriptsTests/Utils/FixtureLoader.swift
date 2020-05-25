//
//  FixtureLoader.swift
//  TranscriptsTests
//
//  Created by Guilherme Rambo on 25/05/20.
//  Copyright © 2020 Guilherme Rambo. All rights reserved.
//

import Foundation
@testable import Transcripts

final class FixtureLoader: Loader {

    func load<T>(from url: URL, decoder: @escaping (Data) throws -> T, completion: @escaping (Result<T, LoaderError>) -> Void) where T: Decodable {
        let filename = url.deletingPathExtension().lastPathComponent
        // swiftlint:disable:next force_try
        let result: T = try! Bundle(for: Self.self).loadJSON(from: filename)
        completion(.success(result))
    }

}
