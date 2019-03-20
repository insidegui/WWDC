//
//  AppleAPIClient.swift
//  WWDC
//
//  Created by Guilherme Rambo on 21/02/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Foundation
import Siesta

// MARK: - Initialization and configuration

public final class AppleAPIClient {

    fileprivate var environment: Environment
    fileprivate var service: Service

    private var environmentChangeToken: NSObjectProtocol?

    public init(environment: Environment) {
        self.environment = environment
        service = Service(baseURL: environment.baseURL)

        configureService()

        environmentChangeToken = NotificationCenter.default.addObserver(forName: .WWDCEnvironmentDidChange, object: nil, queue: .main) { [weak self] _ in
            self?.updateEnvironment()
        }
    }

    deinit {
        if let token = environmentChangeToken {
            NotificationCenter.default.removeObserver(token)
        }
    }



    private func configureService() {
        service.configure("**") { config in
            // Parsing & Transformation is done using Codable, no need to let Siesta do the parsing
            config.pipeline[.parsing].removeTransformers()
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .formatted(.confCoreFormatter)

        service.configureTransformer(environment.newsPath) { (entity: Entity<Data>) throws -> [NewsItem]? in
            struct NewsItemWrapper: Decodable {
                let items: [NewsItem]
            }

            let result = try decoder.decode(NewsItemWrapper.self, from: entity.content).items
            return result
        }

        service.configureTransformer(environment.featuredSectionsPath) { (entity: Entity<Data>) throws -> [FeaturedSection]? in
            struct FeaturedContentWrapper: Decodable {
                let sections: [FeaturedSection]
            }

            let result = try decoder.decode(FeaturedContentWrapper.self, from: entity.content).sections
            return result
        }

        service.configureTransformer(environment.sessionsPath) { (entity: Entity<Data>) throws -> ContentsResponse? in
            return try decoder.decode(ContentsResponse.self, from: entity.content)
        }

        service.configureTransformer(environment.videosPath) { (entity: Entity<Data>) throws -> SessionsResponse? in
            return try decoder.decode(SessionsResponse.self, from: entity.content)
        }

        service.configureTransformer(environment.liveVideosPath) { (entity: Entity<Data>) throws -> [SessionAsset]? in
            return try decoder.decode(LiveVideosWrapper.self, from: entity.content).liveAssets
        }
    }

    fileprivate func updateEnvironment() {
        currentLiveVideosRequest?.cancel()
        currentScheduleRequest?.cancel()
        currentSessionsRequest?.cancel()
        currentNewsItemsRequest?.cancel()
        currentFeaturedSectionsRequest?.cancel()

        environment = Environment.current

        service = Service(baseURL: environment.baseURL)
        liveVideoAssets = makeLiveVideosResource()
        sessions = makeSessionsResource()
        schedule = makeScheduleResource()
        news = makeNewsResource()
        featuredSections = makeFeaturedSectionsResource()
    }

    // MARK: - Resources

    fileprivate lazy var liveVideoAssets: Resource = self.makeLiveVideosResource()

    fileprivate lazy var sessions: Resource = self.makeSessionsResource()

    fileprivate lazy var schedule: Resource = self.makeScheduleResource()

    fileprivate lazy var news: Resource = self.makeNewsResource()

    fileprivate lazy var featuredSections: Resource = self.makeFeaturedSectionsResource()

    fileprivate func makeLiveVideosResource() -> Resource {
        return service.resource(environment.liveVideosPath)
    }

    fileprivate func makeSessionsResource() -> Resource {
        return service.resource(environment.videosPath)
    }

    fileprivate func makeScheduleResource() -> Resource {
        return service.resource(environment.sessionsPath)
    }

    fileprivate func makeNewsResource() -> Resource {
        return service.resource(environment.newsPath)
    }

    fileprivate func makeFeaturedSectionsResource() -> Resource {
        return service.resource(environment.featuredSectionsPath)
    }

    // MARK: - Standard API requests

    private var liveVideoAssetsResource: Resource!
    private var contentsResource: Resource!
    private var sessionsResource: Resource!
    private var newsItemsResource: Resource!
    private var featuredSectionsResource: Resource!

    private var currentLiveVideosRequest: Request?
    private var currentScheduleRequest: Request?
    private var currentSessionsRequest: Request?
    private var currentNewsItemsRequest: Request?
    private var currentFeaturedSectionsRequest: Request?

    public func fetchLiveVideoAssets(completion: @escaping (Result<[SessionAsset], APIError>) -> Void) {
        if liveVideoAssetsResource == nil {
            liveVideoAssetsResource = liveVideoAssets.addObserver(owner: self) { [weak self] resource, event in
                self?.process(resource, event: event, with: completion)
            }
        }

        currentLiveVideosRequest?.cancel()
        currentLiveVideosRequest = liveVideoAssetsResource.load()
    }

    public func fetchContent(completion: @escaping (Result<ContentsResponse, APIError>) -> Void) {
        if contentsResource == nil {
            contentsResource = schedule.addObserver(owner: self) { [weak self] resource, event in
                self?.process(resource, event: event, with: completion)
            }
        }

        currentScheduleRequest?.cancel()
        currentScheduleRequest = contentsResource.loadIfNeeded()
    }

    public func fetchNewsItems(completion: @escaping (Result<[NewsItem], APIError>) -> Void) {
        if newsItemsResource == nil {
            newsItemsResource = news.addObserver(owner: self) { [weak self] resource, event in
                self?.process(resource, event: event, with: completion)
            }
        }

        currentNewsItemsRequest?.cancel()
        currentNewsItemsRequest = newsItemsResource.loadIfNeeded()
    }

    public func fetchFeaturedSections(completion: @escaping (Result<[FeaturedSection], APIError>) -> Void) {
        if featuredSectionsResource == nil {
            featuredSectionsResource = featuredSections.addObserver(owner: self) { [weak self] resource, event in
                self?.process(resource, event: event, with: completion)
            }
        }

        currentFeaturedSectionsRequest?.cancel()
        currentFeaturedSectionsRequest = featuredSectionsResource.loadIfNeeded()
    }

}

// MARK: - API results processing

extension AppleAPIClient {

    fileprivate func process<M>(_ resource: Resource, event: ResourceEvent, with completion: @escaping (Result<M, APIError>) -> Void) {
        switch event {
        case .error:
            completion(.error(resource.error))
        case .newData:
            if let results: M = resource.typedContent() {
                completion(.success(results))
            } else {
                completion(.error(.adapter))
            }
        default: break
        }
    }

}
