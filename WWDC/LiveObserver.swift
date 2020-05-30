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
import os.log

final class LiveObserver: NSObject {

    private let log = OSLog(subsystem: "WWDC", category: "LiveObserver")
    private let dateProvider: DateProvider
    private let storage: Storage
    private let syncEngine: SyncEngine

    private var refreshTimer: Timer?

    var isRunning = false

    private let specialEventsObserver: CloudKitLiveObserver

    init(dateProvider: @escaping DateProvider, storage: Storage, syncEngine: SyncEngine) {
        self.dateProvider = dateProvider
        self.storage = storage
        self.syncEngine = syncEngine
        specialEventsObserver = CloudKitLiveObserver(storage: storage)
    }

    var isWWDCWeek: Bool {
        return storage.realm.objects(Event.self).filter("startDate <= %@ AND endDate > %@ ", dateProvider(), dateProvider()).count > 0
    }

    func start() {
        guard !isRunning else { return }

        os_log("start()", log: log, type: .debug)

        clearLiveSessions()

        specialEventsObserver.fetch()

        guard isWWDCWeek else {
            os_log("Not starting the live event observer because WWDC is not this week",
                   log: log,
                   type: .debug)

            isRunning = false
            return
        }

        isRunning = true

        refreshTimer = Timer.scheduledTimer(withTimeInterval: Constants.liveSessionCheckInterval, repeats: true, block: { [weak self] _ in
            self?.checkForLiveSessions()
        })
        refreshTimer?.tolerance = Constants.liveSessionCheckTolerance
    }

    /// Clears the live flag for all live sessions
    private func clearLiveSessions() {
        storage.modify(allLiveInstances.toArray()) { instances in
            instances.forEach { instance in
                instance.isCurrentlyLive = false
                instance.isForcedLive = false
            }
        }
    }

    func refresh() {
        NSObject.cancelPreviousPerformRequests(withTarget: self)
        perform(#selector(checkForLiveSessions), with: nil, afterDelay: 0)
    }

    private var allLiveInstances: Results<SessionInstance> {
        return storage.realm.objects(SessionInstance.self).filter("isCurrentlyLive == true")
    }

    @objc private func checkForLiveSessions() {
        os_log("checkForLiveSessions()", log: log, type: .debug)

        specialEventsObserver.fetch()

        syncEngine.syncLiveVideos { [weak self] in
            self?.updateLiveFlags()
        }
    }

    private func updateLiveFlags() {
        guard let startTime = Calendar.current.date(byAdding: DateComponents(minute: Constants.liveSessionStartTimeTolerance), to: dateProvider()) else {
            os_log("Could not compute a start time to check for live sessions!", log: log, type: .fault)
            return
        }

        guard let endTime = Calendar.current.date(byAdding: DateComponents(minute: Constants.liveSessionEndTimeTolerance), to: dateProvider()) else {
            os_log("Could not compute an end time to check for live sessions!", log: log, type: .fault)
            return
        }

        let previouslyLiveInstances = allLiveInstances.toArray()
        var notLiveAnymore: [SessionInstance] = []

        os_log("Looking for live instances with startTime <= %{public}@ and endTime >= %{public}@", log: log, type: .debug, String(describing: startTime), String(describing: endTime))

        let liveInstances = storage.realm.objects(SessionInstance.self).filter("startTime <= %@ AND endTime >= %@ AND SUBQUERY(session.assets, $asset, $asset.rawAssetType == %@ AND $asset.actualEndDate == nil).@count > 0", startTime, endTime, SessionAssetType.liveStreamVideo.rawValue)

        previouslyLiveInstances.forEach { instance in
            if !liveInstances.contains(instance) {
                notLiveAnymore.append(instance)
            }
        }

        setLiveFlag(false, for: notLiveAnymore)
        setLiveFlag(true, for: liveInstances.toArray())

        os_log("There are %{public}d live instances. %{public}d instances are not live anymore",
               log: log,
               type: .debug,
               liveInstances.count,
               notLiveAnymore.count)

        let liveIdentifiers: [String] = liveInstances.map({ $0.identifier })
        let notLiveAnymoreIdentifiers: [String] = notLiveAnymore.map({ $0.identifier })

        if liveIdentifiers.count > 0 {
            os_log("The following sessions are currently live: %{public}@", log: log, type: .debug, liveIdentifiers.joined(separator: ","))
        } else {
            os_log("There are no live sessions at the moment", log: log, type: .debug)
        }

        if notLiveAnymoreIdentifiers.count > 0 {
            os_log("The following sessions are NOT live anymore: %{public}@", log: log, type: .debug, notLiveAnymoreIdentifiers.joined(separator: ","))
        } else {
            os_log("There are no sessions that were live and are not live anymore", log: log, type: .debug)
        }
    }

    private func setLiveFlag(_ value: Bool, for instances: [SessionInstance]) {
        os_log("Setting live flag to %{public}@ for %{public}d instances",
               log: log,
               type: .info,
               String(describing: value), instances.count)

        storage.modify(instances) { bgInstances in
            bgInstances.forEach { instance in
                guard !instance.isForcedLive else { return }

                instance.isCurrentlyLive = value
            }
        }
    }

    func processSubscriptionNotification(with userInfo: [String: Any]) -> Bool {
        return specialEventsObserver.processSubscriptionNotification(with: userInfo)
    }

}

private extension SessionAsset {

    static var recordType: String {
        return "LiveSession"
    }

    convenience init?(record: CKRecord) {
        guard let sessionIdentifier = record["sessionIdentifier"] as? String else { return nil }
        guard let hls = record["hls"] as? String else { return nil }

        self.init()

        assetType = .liveStreamVideo
        year = Calendar.current.component(.year, from: today())
        sessionId = sessionIdentifier
        remoteURL = hls
        identifier = generateIdentifier()
    }

}

private final class CloudKitLiveObserver {

    private let log = OSLog(subsystem: "WWDC", category: "CloudKitLiveObserver")
    private let storage: Storage

    private lazy var database: CKDatabase = CKContainer.default().publicCloudDatabase

    init(storage: Storage) {
        self.storage = storage

        createSubscriptionIfNeeded()
    }

    func fetch() {
        #if ICLOUD
            let query = CKQuery(recordType: SessionAsset.recordType, predicate: NSPredicate(value: true))
            let operation = CKQueryOperation(query: query)

            var fetchedRecords: [CKRecord] = []

            operation.recordFetchedBlock = { record in
                fetchedRecords.append(record)
            }

            operation.queryCompletionBlock = { [unowned self] _, error in
                if let error = error {
                    os_log("Error fetching special live records: %{public}@",
                           log: self.log,
                           type: .error,
                           String(describing: error))

                    DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                        self.fetch()
                    }
                } else {
                    DispatchQueue.main.async { self.store(fetchedRecords) }
                }
            }

            database.add(operation)
        #endif
    }

    private func createSubscriptionIfNeeded() {
        #if ICLOUD
            CloudKitHelper.subscriptionExists(with: specialLiveEventsSubscriptionID, in: database) { [unowned self] exists in
                if !exists {
                    self.doCreateSubscription()
                }
            }
        #endif
    }

    private func doCreateSubscription() {
        #if ICLOUD
            let options: CKQuerySubscription.Options = [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion]
            let subscription = CKQuerySubscription(recordType: SessionAsset.recordType,
                                                   predicate: NSPredicate(value: true),
                                                   subscriptionID: specialLiveEventsSubscriptionID,
                                                   options: options)

            database.save(subscription) { _, error in
                if let error = error {
                    os_log("Error creating subscriptions: %{public}@",
                           log: self.log,
                           type: .error,
                           String(describing: error))
                } else {
                    os_log("Subscriptions created", log: self.log, type: .info)
                }
            }
        #endif
    }

    private let specialLiveEventsSubscriptionID: String = "SPECIAL-LIVE-EVENTS"

    func processSubscriptionNotification(with userInfo: [String: Any]) -> Bool {
        #if ICLOUD
            let notification = CKNotification(fromRemoteNotificationDictionary: userInfo)

            // check if the remote notification is for us, if not, tell the caller that we haven't handled it
            guard notification?.subscriptionID == specialLiveEventsSubscriptionID else { return false }

            // notification for special live events, just fetch everything again
            fetch()

            return true
        #else
            return false
        #endif
    }

    private func store(_ records: [CKRecord]) {
        os_log("Storing live records", log: log, type: .debug)

        storage.backgroundUpdate { realm in
            records.forEach { record in
                guard let asset = SessionAsset(record: record) else { return }
                guard let session = realm.object(ofType: Session.self, forPrimaryKey: asset.sessionId) else { return }
                guard let instance = session.instances.first else { return }

                if let existingAsset = realm.object(ofType: SessionAsset.self, forPrimaryKey: asset.identifier) {
                    // update existing asset hls URL if appropriate
                    existingAsset.remoteURL = asset.remoteURL
                } else {
                    // add new live asset to corresponding session
                    session.assets.append(asset)
                }

                instance.isForcedLive = (record["isLive"] as? Int == 1)
                instance.isCurrentlyLive = instance.isForcedLive
            }
        }
    }

}
