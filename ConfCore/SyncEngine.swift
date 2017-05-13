//
//  SyncEngine.swift
//  WWDC
//
//  Created by Guilherme Rambo on 22/04/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Foundation
import RxSwift

extension Notification.Name {
    public static let SyncEngineDidSyncSessionsAndSchedule = Notification.Name("SyncEngineDidSyncSessionsAndSchedule")
}

public final class SyncEngine {
    
    public let storage: Storage
    public let client: AppleAPIClient
    
    public init(storage: Storage, client: AppleAPIClient) {
        self.storage = storage
        self.client = client
    }
    
    public func syncSessionsAndSchedule() {
        client.fetchSessions { [weak self] sessionsResult in
            DispatchQueue.main.async {
                self?.client.fetchSchedule { scheduleResult in
                    DispatchQueue.main.async {
                        self?.storage.store(sessionsResult: sessionsResult, scheduleResult: scheduleResult) {
                            NotificationCenter.default.post(name: .SyncEngineDidSyncSessionsAndSchedule, object: self)
                        }
                    }
                }
            }
        }
    }
    
    public func syncLiveVideos() {
        client.fetchLiveVideoAssets { [weak self] result in
            DispatchQueue.main.async {
                self?.storage.store(liveVideosResult: result)
            }
        }
    }
    
}
