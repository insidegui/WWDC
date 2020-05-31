//
//  CocoaHubAPIClient.swift
//  ConfCore
//
//  Created by Guilherme Rambo on 31/05/20.
//  Copyright © 2020 Guilherme Rambo. All rights reserved.
//

import Cocoa
import Siesta

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

        service.configureTransformer(Routes.news) { (entity: Entity<Data>) throws -> [CommunityNewsItem]? in
            struct ResponseWrapper: Decodable {
                let news: [CommunityNewsItem]
            }

            do {
                return try decoder.decode(ResponseWrapper.self, from: entity.content).news
            } catch {
                throw error
            }
        }
    }

    private struct Routes {
        static let news = "/"
    }

    fileprivate func updateEnvironment() {
        environment = Environment.current

        service = Service(baseURL: environment.cocoaHubBaseURL)
    }

    private lazy var newsResource: Resource = {
        service.resource(Routes.news)
    }()

    private var observers: [Resource] = []

    func fetchNews(completion: @escaping (Result<[CommunityNewsItem], APIError>) -> Void) {
        newsResource.removeObservers(ownedBy: self)
        newsResource.invalidate()

        let observer = newsResource.addObserver(owner: self) { resource, event in
            Resource.process(resource, event: event, with: completion)
        }
        observers.append(observer)

        newsResource.loadIfNeeded()
    }

    deinit {
        if let token = environmentChangeToken {
            NotificationCenter.default.removeObserver(token)
        }
    }

}
