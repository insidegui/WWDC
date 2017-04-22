//
//  SyncEngine.swift
//  WWDC
//
//  Created by Guilherme Rambo on 22/04/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Foundation
import RxSwift

public final class SyncEngine {
    
    public let storage: Storage
    public let client: AppleAPIClient
    
    public init(storage: Storage, client: AppleAPIClient) {
        self.storage = storage
        self.client = client
    }
    
    public func syncSessionsAndSchedule(completion: @escaping (APIError?) -> Void) {
        client.fetchSessions { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .error(let error):
                    completion(error)
                case .success(let response):
                    self?.storage.store(sessionsResponse: response)
                    
                    self?.client.fetchSchedule { result in
                        DispatchQueue.main.async {
                            switch result {
                            case .error(let error):
                                completion(error)
                            case .success(let response):
                                self?.storage.store(schedule: response)
                                completion(nil)
                            }
                        }
                    }
                }
            }
        }
    }
    
}
