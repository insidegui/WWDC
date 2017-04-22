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
        client.fetchSessions { [weak self] sessionsResult in
            DispatchQueue.main.async {
                self?.client.fetchSchedule { scheduleResult in
                    DispatchQueue.main.async {
                        self?.storage.store(sessionsResult: sessionsResult, scheduleResult: scheduleResult)
                    }
                }
            }
        }
    }
    
}
