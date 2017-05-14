//
//  LiveObserver.swift
//  WWDC
//
//  Created by Guilherme Rambo on 13/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Foundation
import ConfCore
import RealmSwift

final class LiveObserver {
    
    private let dateProvider: DateProvider
    private let storage: Storage
    
    private var timer: Timer?
    
    var isRunning = false
    
    init(dateProvider: @escaping DateProvider, storage: Storage) {
        self.dateProvider = dateProvider
        self.storage = storage
    }
    
    func start() {
        guard !isRunning else { return }
        
        guard storage.realm.objects(Event.self).filter("startDate <= %@ AND endDate > %@ ", dateProvider(), dateProvider()).count > 0 else {
            NSLog("Live event observer not started because we're not on WWDC week")
            isRunning = false
            return
        }
        
        isRunning = true
        
        NSLog("Live event observer started")
        
        self.timer = Timer.scheduledTimer(timeInterval: Constants.liveSessionCheckInterval, target: self, selector: #selector(checkForLiveSessions(_:)), userInfo: nil, repeats: true)
        
        // This timer doesn't have to be very precise, giving it a tolerance improves CPU and battery usage ;)
        self.timer?.tolerance = 10.0
        
        checkForLiveSessions(nil)
    }
    
    private var allLiveInstances: Results<SessionInstance> {
        return storage.realm.objects(SessionInstance.self).filter("isCurrentlyLive == true")
    }
    
    @objc private func checkForLiveSessions(_ sender: Any?) {
        let startTime = dateProvider()
        let endTime = dateProvider().addingTimeInterval(Constants.liveSessionEndTimeTolerance)
        
        let previouslyLiveInstances = allLiveInstances.toArray()
        var notLiveAnymore: [SessionInstance] = []
        
        let liveInstances = storage.realm.objects(SessionInstance.self).filter("startTime <= %@ AND endTime > %@ AND SUBQUERY(session.assets, $asset, $asset.rawAssetType == %@).@count > 0", startTime, endTime, SessionAssetType.liveStreamVideo.rawValue)
        
        previouslyLiveInstances.forEach { instance in
            if !liveInstances.contains(instance) {
                notLiveAnymore.append(instance)
            }
        }
        
        setLiveFlag(false, for: notLiveAnymore)
        setLiveFlag(true, for: liveInstances.toArray())
    }
    
    private func setLiveFlag(_ value: Bool, for instances: [SessionInstance]) {
        do {
            try storage.realm.write {
                // reset live flag for every instance
                instances.forEach { instance in
                    instance.isCurrentlyLive = value
                }
            }
        } catch {
            NSLog("Error resetting live flags: \(error)")
        }
    }
    
}
