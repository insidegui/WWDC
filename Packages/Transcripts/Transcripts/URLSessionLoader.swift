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

    private let log = OSLog(subsystem: Transcripts.subsystemName, category: String(describing: URLSessionLoader.self))

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
                    os_log("Error loading from %@: %{public}@", log: self.log, type: .error, url.absoluteString, String(describing: error))

                    completion(.failure(LoaderError.networking(error)))
                } else if let response = response as? HTTPURLResponse {
                    os_log("HTTP error loading from %@: %d", log: self.log, type: .error, url.absoluteString, response.statusCode)

                    completion(.failure(.http(response.statusCode)))
                } else {
                    os_log("Error loading from %@: no data", log: self.log, type: .error, url.absoluteString)

                    completion(.failure(LoaderError(localizedDescription: "No data returned from the server.")))
                }

                return
            }

            do {
                let decoded = try decoder(data)

                completion(.success(decoded))
            } catch {
                os_log("Failed to decode %@ from %@: %{public}@", log: self.log, type: .error, String(describing: T.self), url.absoluteString, String(describing: error))

                completion(.failure(.serialization(error)))
            }
        }.resume()
    }

}
