//
//  AppleAPIClient.swift
//  WWDC
//
//  Created by Guilherme Rambo on 21/02/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Foundation
import Siesta
import SwiftyJSON

// MARK: - Initialization and configuration

public final class AppleAPIClient {
    
    fileprivate let environment: Environment
    fileprivate let service: Service
    
    public init(environment: Environment) {
        self.environment = environment
        self.service = Service(baseURL: environment.baseURL)
        
        configureService()
    }
    
    private let jsonParser = ResponseContentTransformer { JSON($0.content as AnyObject) }
    
    private func configureService() {
        service.configure("**") { config in
            config.pipeline[.parsing].add(self.jsonParser, contentTypes: ["*/json"])
        }
        
        service.configureTransformer(environment.newsPath) { [weak self] (entity: Entity<JSON>) throws -> [NewsItem]? in
            let json = entity.content as JSON
            
            guard let newsItemsJson = json["items"].array else {
                throw APIError.adapter
            }
            
            return try self?.failableAdaptCollection(newsItemsJson, using: NewsItemsJSONAdapter())
        }
        
        service.configureTransformer(environment.sessionsPath) { [weak self] (entity: Entity<JSON>) throws -> ScheduleResponse? in
            let json = entity.content as JSON
            
            return try self?.failableAdapt(json, using: ScheduleResponseAdapter())
        }
        
        service.configureTransformer(environment.videosPath) { [weak self] (entity: Entity<JSON>) throws -> SessionsResponse? in
            let json = entity.content as JSON
            
            return try self?.failableAdapt(json, using: SessionsResponseAdapter())
        }

        service.configureTransformer(environment.liveVideosPath) { [weak self] (entity: Entity<JSON>) throws -> [SessionAsset]? in
            let json = entity.content as JSON
            
            guard let sessionsDict = json["live_sessions"].dictionary else {
                throw APIError.adapter
            }
            
            let sessionsArray = sessionsDict.flatMap { key, value -> JSON? in
                guard let id = JSON.init(rawValue: key) else { return nil }
                
                var v = value
                
                v["sessionId"] = id
                
                return v
            }

            return try self?.failableAdaptCollection(sessionsArray, using: LiveVideosAdapter())
        }
    }
    
    // MARK: - Resources
    
    fileprivate lazy var liveVideoAssets: Resource = {
        return self.service.resource(self.environment.liveVideosPath)
    }()
    
    fileprivate lazy var sessions: Resource = {
        return self.service.resource(self.environment.videosPath)
    }()
    
    fileprivate lazy var schedule: Resource = {
        return self.service.resource(self.environment.sessionsPath)
    }()
    
    fileprivate lazy var news: Resource = {
        return self.service.resource(self.environment.newsPath)
    }()
    
}

// MARK: - Standard API requests

extension AppleAPIClient {

    public func fetchLiveVideoAssets(completion: @escaping (Result<[SessionAsset], APIError>) -> Void) {
        liveVideoAssets.addObserver(owner: self) { [weak self] resource, event in
            self?.process(resource, event: event, with: completion)
        }.loadIfNeeded()
    }
    
    public func fetchSchedule(completion: @escaping (Result<ScheduleResponse, APIError>) -> Void) {
        schedule.addObserver(owner: self) { [weak self] resource, event in
            self?.process(resource, event: event, with: completion)
        }.loadIfNeeded()
    }
    
    public func fetchSessions(completion: @escaping (Result<SessionsResponse, APIError>) -> Void) {
        sessions.addObserver(owner: self) { [weak self] resource, event in
            self?.process(resource, event: event, with: completion)
        }.loadIfNeeded()
    }
    
    public func fetchNewsItems(completion: @escaping (Result<[NewsItem], APIError>) -> Void) {
        news.addObserver(owner: self) { [weak self] resource, event in
            self?.process(resource, event: event, with: completion)
        }.loadIfNeeded()
    }
    
}

// MARK: - API results processing

extension AppleAPIClient {
    
    /// Convenience method to use a model adapter as a method that returns the model(s) or throws an error
    fileprivate func failableAdapt<A: Adapter, T>(_ input: JSON, using adapter: A) throws -> T where A.InputType == JSON, A.OutputType == T {
        let result = adapter.adapt(input)
        
        switch result {
        case .error(let error):
            throw error
        case .success(let output):
            return output
        }
    }
    
    /// Convenience method to use a model adapter as a method that returns the model(s) or throws an error
    fileprivate func failableAdaptCollection<A: Adapter, T>(_ input: [JSON], using adapter: A) throws -> [T] where A.InputType == JSON, A.OutputType == T {
        let result = adapter.adapt(input)
        
        switch result {
        case .error(let error):
            throw error
        case .success(let output):
            return output
        }
    }
    
    fileprivate func process<M>(_ resource: Resource, event: ResourceEvent, with completion: @escaping (Result<M, APIError>) -> ()) {
        switch event {
        case .error:
            completion(.error(resource.error))
        case .newData(_), .notModified:
            if let results: M = resource.typedContent() {
                completion(.success(results))
            } else {
                completion(.error(.adapter))
            }
        default: break
        }
    }
    
}
