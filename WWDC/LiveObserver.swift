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
import CloudKit

final class LiveObserver {
    
    private let dateProvider: DateProvider
    private let storage: Storage
    
    private var timer: Timer?
    
    var isRunning = false
    
    private let specialEventsObserver: CloudKitLiveObserver
    
    init(dateProvider: @escaping DateProvider, storage: Storage) {
        self.dateProvider = dateProvider
        self.storage = storage
        self.specialEventsObserver = CloudKitLiveObserver(storage: storage)
    }
    
    var isWWDCWeek: Bool {
        return storage.realm.objects(Event.self).filter("startDate <= %@ AND endDate > %@ ", dateProvider(), dateProvider()).count > 0
    }
    
    func start() {
        guard !isRunning else { return }
        
        specialEventsObserver.fetch()
        
        guard isWWDCWeek else {
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
                    guard !instance.isForcedLive else { return }
                    
                    instance.isCurrentlyLive = value
                }
            }
        } catch {
            NSLog("Error resetting live flags: \(error)")
        }
    }
    
    func processSubscriptionNotification(with userInfo: [String : Any]) -> Bool {
        return self.specialEventsObserver.processSubscriptionNotification(with: userInfo)
    }
    
}

private extension SessionAsset {
    
    static var recordType: String {
        return "LiveSession"
    }
    
    convenience init?(record: CKRecord) {
        guard let number = record["sessionNumber"] as? Int else { return nil }
        guard let hls = record["hls"] as? String else { return nil }
        
        self.init()
        
        self.assetType = .liveStreamVideo
        self.sessionId = "\(number)"
        self.remoteURL = hls
        self.year = Calendar.current.component(.year, from: Today())
    }
    
}

private final class CloudKitLiveObserver: NSObject {
    
    private let storage: Storage
    
    private lazy var database: CKDatabase = CKContainer.default().publicCloudDatabase
    
    init(storage: Storage) {
        self.storage = storage
        
        super.init()
    }
    
    func fetch() {
        let query = CKQuery(recordType: SessionAsset.recordType, predicate: NSPredicate(value: true))
        let operation = CKQueryOperation(query: query)
        
        var fetchedRecords: [CKRecord] = []
        
        operation.recordFetchedBlock = { record in
            fetchedRecords.append(record)
        }
        
        operation.queryCompletionBlock = { [unowned self] _, error in
            if let error = error {
                NSLog("Error fetching special live videos: \(error)")
                DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                    self.fetch()
                }
            } else {
                DispatchQueue.main.async { self.store(fetchedRecords) }
            }
        }
        
        database.add(operation)
        
        subscribeIfNeeded()
    }
    
    private func subscribeIfNeeded() {
        guard subscriptionID == nil else { return }
        
        let options: CKQuerySubscriptionOptions = [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion]
        let subscription = CKQuerySubscription(recordType: SessionAsset.recordType,
                                               predicate: NSPredicate(value: true),
                                               options: options)
        
        database.save(subscription) { [unowned self] savedSubscription, error in
            self.subscriptionID = savedSubscription?.subscriptionID
        }
    }
    
    private let subscriptionDefaultsKey = "specialEventsLiveObserverCKSubscriptionID"
    
    private var subscriptionID: String? {
        get {
            return UserDefaults.standard.object(forKey: subscriptionDefaultsKey) as? String
        }
        set {
            UserDefaults.standard.set(newValue, forKey: subscriptionDefaultsKey)
        }
    }
    
    func processSubscriptionNotification(with userInfo: [String : Any]) -> Bool {
        let notification = CKNotification(fromRemoteNotificationDictionary: userInfo)
        
        // check if the remote notification is for us, if not, tell the caller that we haven't handled it
        guard notification.subscriptionID == self.subscriptionID else { return false }
        
        // notification for special live events, just fetch everything again
        fetch()
        
        return true
    }
    
    private func store(_ records: [CKRecord]) {
        print("storing live records")
        
        storage.unmanagedUpdate { [unowned self] realm in
            records.forEach { record in
                guard let asset = SessionAsset(record: record) else { return }
                guard let instance = self.storage.session(with: "\(asset.year)-\(asset.sessionId)")?.instances.first else { return }
                
                instance.isForcedLive = (record["isLive"] as? Int == 1)
                instance.isCurrentlyLive = instance.isForcedLive
            }
        }
    }
    
}
