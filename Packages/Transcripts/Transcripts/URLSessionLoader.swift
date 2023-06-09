//
//  URLSessionLoader.swift
//  Transcripts
//
//  Created by Guilherme Rambo on 25/05/20.
//  Copyright © 2020 Guilherme Rambo. All rights reserved.
//

import Foundation
import os.log

public final class URLSessionLoader: Loader {

    public init() { }

    private let log = Logger(subsystem: Transcripts.subsystemName, category: String(describing: URLSessionLoader.self))

    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.waitsForConnectivity = true
        return URLSession(configuration: config)
    }()

    public func load<T>(from url: URL, decoder: @escaping (Data) throws -> T, completion: @escaping (Result<T, LoaderError>) -> Void) where T: Decodable {
        session.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else { return }

            guard let data = data else {
                if let error = error {
                    self.log.error("Error loading from \(url.absoluteString, privacy: .public): \(String(describing: error), privacy: .public)")

                    completion(.failure(LoaderError.networking(error)))
                } else if let response = response as? HTTPURLResponse {
                    self.log.error("HTTP error loading from \(url.absoluteString, privacy: .public): \(response.statusCode)")

                    completion(.failure(.http(response.statusCode)))
                } else {
                    self.log.error("Error loading from \(url.absoluteString, privacy: .public): no data")

                    completion(.failure(LoaderError(localizedDescription: "No data returned from the server.")))
                }

                return
            }

            do {
                let decoded = try decoder(data)

                completion(.success(decoded))
            } catch {
                self.log.error("Failed to decode \(String(describing: T.self), privacy: .public) from \(url.absoluteString, privacy: .public): \(String(describing: error), privacy: .public)")

                completion(.failure(.serialization(error)))
            }
        }.resume()
    }

}
