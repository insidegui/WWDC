//
//  Loader.swift
//  Transcripts
//
//  Created by Guilherme Rambo on 25/05/20.
//  Copyright © 2020 Guilherme Rambo. All rights reserved.
//

import Foundation

public protocol Loader {
    func load<T: Decodable>(from url: URL, decoder: @escaping (Data) throws -> T, completion: @escaping (Result<T, LoaderError>) -> Void)
}

public struct LoaderError: LocalizedError {
    public var localizedDescription: String

    public static func http(_ code: Int) -> LoaderError {
        LoaderError(localizedDescription: "HTTP error \(code)")
    }

    public static func networking(_ error: Error) -> LoaderError {
        if let suggestion = (error as NSError).localizedRecoverySuggestion {
            return LoaderError(localizedDescription: "A networking error occurred.\n\(suggestion)")
        } else {
            return LoaderError(localizedDescription: error.localizedDescription)
        }
    }

    public static func serialization(_ error: Error) -> LoaderError {
        return LoaderError(localizedDescription: error.localizedDescription)
    }

}
