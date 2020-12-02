//
//  CocoaHubAPIClient.swift
//  ConfCore
//
//  Created by Guilherme Rambo on 31/05/20.
//  Copyright © 2020 Guilherme Rambo. All rights reserved.
//

import Cocoa
import Siesta

internal struct CocoaHubIndexResponse: Decodable {
    let tags: [CommunityTag]
    let news: [CommunityNewsItem]
    let editions: [CocoaHubEdition]
}

internal struct CocoaHubEditionResponse: Decodable {
    let _id: String
    let articles: [CommunityNewsItem]
}

public final class CocoaHubAPIClient {

    private var environment: Environment
    private var service: Service

    private var environmentChangeToken: NSObjectProtocol?

    public init(environment: Environment) {
        self.environment = environment
        service = Service(baseURL: environment.cocoaHubBaseURL)

        configureService()

        environmentChangeToken = NotificationCenter.default.addObserver(forName: .WWDCEnvironmentDidChange, object: nil, queue: .main) { [weak self] _ in
            self?.updateEnvironment()
        }
    }

    private func configureService() {
        service.configure("**") { config in
            config.pipeline[.parsing].removeTransformers()
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        service.configureTransformer(Routes.news) { (entity: Entity<Data>) throws -> CocoaHubIndexResponse? in
            do {
                return try decoder.decode(CocoaHubIndexResponse.self, from: entity.content)
            } catch {
                throw error
            }
        }

        service.configureTransformer(Routes.editions) { (entity: Entity<Data>) throws -> CocoaHubEditionResponse? in
            do {
                return try decoder.decode(CocoaHubEditionResponse.self, from: entity.content)
            } catch {
                throw error
            }
        }
    }

    private struct Routes {
        static let news = "/"
        static let editions = "/editions"
    }

    fileprivate func updateEnvironment() {
        environment = Environment.current

        service = Service(baseURL: environment.cocoaHubBaseURL)
    }

    private lazy var newsResource: Resource = {
        service.resource(Routes.news)
    }()

    private func editionResource(with index: Int) -> Resource {
        service.resource(Routes.editions).withParam("id", "\(index)")
    }

    private var observers: [Resource] = []

    func fetchNews(completion: @escaping (Result<CocoaHubIndexResponse, APIError>) -> Void) {
        newsResource.removeObservers(ownedBy: self)
        newsResource.invalidate()

        let observer = newsResource.addObserver(owner: self) { resource, event in
            Resource.process(resource, event: event, with: completion)
        }
        observers.append(observer)

        newsResource.loadIfNeeded()
    }

    func fetchEditionArticles(for index: Int, completion: @escaping (Result<CocoaHubEditionResponse, APIError>) -> Void) {
        let editionResource = self.editionResource(with: index)

        let observer = editionResource.addObserver(owner: self) { resource, event in
            Resource.process(resource, event: event, with: completion)
        }
        observers.append(observer)

        editionResource.loadIfNeeded()
    }

    deinit {
        if let token = environmentChangeToken {
            NotificationCenter.default.removeObserver(token)
        }
    }

}
