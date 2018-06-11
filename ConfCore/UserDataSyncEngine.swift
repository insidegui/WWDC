//
//  UserDataSyncEngine.swift
//  ConfCore
//
//  Created by Guilherme Rambo on 20/05/18.
//  Copyright © 2018 Guilherme Rambo. All rights reserved.
//

import Foundation
import CloudKit
import CloudKitCodable
import RealmSwift
import RxSwift
import os.log

#if ICLOUD
public final class UserDataSyncEngine {

    public init(storage: Storage, defaults: UserDefaults = .standard, container: CKContainer = .default()) {
        self.storage = storage
        self.defaults = defaults
        self.container = container
        self.privateDatabase = container.privateCloudDatabase

        checkAccountAvailability()
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(checkAccountAvailability),
                                               name: .CKAccountChanged,
                                               object: nil)
    }

    private struct Constants {
        static let zoneName = "WWDCV6"
        static let privateSubscriptionId = "wwdcv6-private-changes"
    }

    private let storage: Storage
    private let defaults: UserDefaults
    private let container: CKContainer
    private let privateDatabase: CKDatabase

    private let log = OSLog(subsystem: "ConfCore", category: "UserDataSyncEngine")

    private lazy var cloudOperationQueue: OperationQueue = {
        let q = OperationQueue()

        q.name = "CloudKit"

        return q
    }()

    private let workQueue = DispatchQueue(label: "UserDataSyncEngine")

    private var createdCustomZone: Bool {
        get {
            return defaults.bool(forKey: #function)
        }
        set {
            defaults.set(newValue, forKey: #function)
        }
    }

    private var createdPrivateSubscription: Bool {
        get {
            return defaults.bool(forKey: #function)
        }
        set {
            defaults.set(newValue, forKey: #function)
        }
    }

    private lazy var customZoneID: CKRecordZoneID = {
        return CKRecordZoneID(zoneName: Constants.zoneName, ownerName: CKCurrentUserDefaultName)
    }()

    // MARK: - State management

    public private(set) var isRunning = false

    private var isWaitingForAccountAvailabilityToStart = false

    public var isEnabled = false {
        didSet {
            guard oldValue != isEnabled else { return }

            if isEnabled {
                os_log("Starting because isEnabled has changed to true", log: log, type: .debug)
                start()
            } else {
                isWaitingForAccountAvailabilityToStart = false
                os_log("Stopping because isEnabled has changed to false", log: log, type: .debug)
                stop()
            }
        }
    }

    private let disposeBag = DisposeBag()

    public func start() {
        guard !isWaitingForAccountAvailabilityToStart else { return }
        guard isEnabled else { return }

        #if ICLOUD
        guard !isRunning else { return }

        os_log("Start!", log: log, type: .debug)

        // Only start the sync engine if there's an iCloud account available, if availability is not
        // determined yet, start the sync engine after the account availability is known and == available

        guard isAccountAvailable.value else {
            os_log("iCloud account is not available yet, waiting for availability to start", log: log, type: .info)
            isWaitingForAccountAvailabilityToStart = true

            isAccountAvailable.asObservable().observeOn(MainScheduler.instance).subscribe(onNext: { [unowned self] available in
                guard self.isWaitingForAccountAvailabilityToStart else { return }

                os_log("iCloud account available = %{public}@", log: self.log, type: .info, String(describing: available))

                if available {
                    self.isWaitingForAccountAvailabilityToStart = false
                    self.start()
                }
            }).disposed(by: disposeBag)

            return
        }

        isRunning = true

        startObservingSyncOperations()

        prepareCloudEnvironment { [unowned self] in
            self.incinerateSoftDeletedObjects()
            self.uploadLocalDataNotUploadedYet()
            self.observeLocalChanges()
            self.fetchChanges()
        }
        #endif
    }

    public private(set) var isStopping = Variable<Bool>(false)

    public private(set) var isPerformingSyncOperation = Variable<Bool>(false)

    public private(set) var isAccountAvailable = Variable<Bool>(false)

    public func stop(harsh: Bool = false) {
        guard isRunning, !isStopping.value else { return }
        isStopping.value = true

        workQueue.async { [unowned self] in
            defer {
                DispatchQueue.main.async {
                    self.isStopping.value = false
                    self.isRunning = false
                }
            }

            self.cloudOperationQueue.waitUntilAllOperationsAreFinished()

            DispatchQueue.main.async {
                self.stopObservingSyncOperations()

                self.realmNotificationTokens.forEach { $0.invalidate() }
                self.realmNotificationTokens.removeAll()

                guard harsh else { return }

                self.clearSyncMetadata()
            }
        }
    }

    private var cloudQueueObservation: NSKeyValueObservation?

    private func startObservingSyncOperations() {
        cloudQueueObservation = cloudOperationQueue.observe(\.operationCount) { [unowned self] queue, _ in
            self.isPerformingSyncOperation.value = queue.operationCount > 0
        }
    }

    private func stopObservingSyncOperations() {
        cloudQueueObservation?.invalidate()
        cloudQueueObservation = nil
    }

    // MARK: Account availability

    private var isWaitingForAccountAvailabilityReply = false

    @objc private func checkAccountAvailability() {
        guard !isWaitingForAccountAvailabilityReply else { return }
        isWaitingForAccountAvailabilityReply = true

        os_log("checkAccountAvailability()", log: log, type: .debug)

        container.accountStatus { [unowned self] status, error in
            defer { self.isWaitingForAccountAvailabilityReply = false }

            if let error = error {
                os_log("Failed to determine iCloud account status: %{public}@",
                       log: self.log,
                       type: .error,
                       String(describing: error))
                return
            }

            os_log("iCloud availability status is %{public}d", log: self.log, type: .debug, status.rawValue)

            switch status {
            case .available:
                self.isAccountAvailable.value = true
            default:
                self.isAccountAvailable.value = false
            }
        }
    }

    // MARK: - Cloud environment management

    private func prepareCloudEnvironment(then block: @escaping () -> Void) {
        workQueue.async { [unowned self] in
            self.createCustomZoneIfNeeded()
            self.cloudOperationQueue.waitUntilAllOperationsAreFinished()
            guard self.createdCustomZone else { return }

            self.createPrivateSubscriptionsIfNeeded()
            self.cloudOperationQueue.waitUntilAllOperationsAreFinished()
            guard self.createdPrivateSubscription else { return }

            DispatchQueue.main.async { block() }
        }
    }

    private func createCustomZoneIfNeeded() {
        guard !createdCustomZone else {
            os_log("Already have custom zone, skipping creation", log: log, type: .debug)
            return
        }

        os_log("Creating CloudKit zone %@", log: log, type: .info, Constants.zoneName)

        let zone = CKRecordZone(zoneID: customZoneID)
        let operation = CKModifyRecordZonesOperation(recordZonesToSave: [zone], recordZoneIDsToDelete: nil)

        operation.modifyRecordZonesCompletionBlock = { [unowned self] _, _, error in
            if let error = error {
                os_log("Failed to create custom CloudKit zone: %{public}@",
                       log: self.log,
                       type: .error,
                       String(describing: error))

                error.retryCloudKitOperationIfPossible(self.log) { self.createCustomZoneIfNeeded() }
            } else {
                os_log("Zone created successfully", log: self.log, type: .info)
                self.createdCustomZone = true
            }
        }

        operation.qualityOfService = .userInitiated
        operation.database = privateDatabase

        cloudOperationQueue.addOperation(operation)
    }

    private func createPrivateSubscriptionsIfNeeded() {
        guard !createdPrivateSubscription else {
            os_log("Already subscribed to private database changes, skipping subscription", log: log, type: .debug)
            return
        }

        let subscription = CKDatabaseSubscription(subscriptionID: Constants.privateSubscriptionId)

        let notificationInfo = CKNotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        subscription.notificationInfo = notificationInfo

        let operation = CKModifySubscriptionsOperation(subscriptionsToSave: [subscription], subscriptionIDsToDelete: nil)

        operation.modifySubscriptionsCompletionBlock = { [unowned self] _, _, error in
            if let error = error {
                os_log("Failed to create private CloudKit subscription: %{public}@",
                       log: self.log,
                       type: .error,
                       String(describing: error))

                error.retryCloudKitOperationIfPossible(self.log) { self.createPrivateSubscriptionsIfNeeded() }
            } else {
                os_log("Private subscription created successfully", log: self.log, type: .info)
                self.createdPrivateSubscription = true
            }
        }

        operation.database = privateDatabase
        operation.qualityOfService = .utility

        cloudOperationQueue.addOperation(operation)
    }

    private func clearSyncMetadata() {
        privateChangeToken = nil
        createdPrivateSubscription = false
        createdCustomZone = false

        clearCloudKitFields(for: Favorite.self)
        clearCloudKitFields(for: SessionProgress.self)
        clearCloudKitFields(for: Bookmark.self)
    }

    private func clearCloudKitFields<T: SynchronizableRealmObject>(for objectType: T.Type) {
        performRealmOperations { realm in
            realm.objects(objectType).forEach { model in
                var mutableModel = model
                mutableModel.ckFields = Data()
            }
        }
    }

    // MARK: - Silent notifications

    public func processSubscriptionNotification(with userInfo: [String: Any]) -> Bool {
        guard isEnabled, isRunning else { return false }

        let notification = CKNotification(fromRemoteNotificationDictionary: userInfo)

        guard notification.subscriptionID == Constants.privateSubscriptionId else { return false }

        os_log("Received remote CloudKit notification for user data", log: log, type: .debug)

        fetchChanges()

        return true
    }

    // MARK: - Data syncing

    private var privateChangeToken: CKServerChangeToken? {
        get {
            guard let data = defaults.data(forKey: #function) else { return nil }

            guard let token = NSKeyedUnarchiver.unarchiveObject(with: data) as? CKServerChangeToken else {
                os_log("Failed to decode CKServerChangeToken from defaults key privateChangeToken", log: log, type: .error)
                return nil
            }

            return token
        }
        set {
            guard let newValue = newValue else {
                defaults.setNilValueForKey(#function)
                return
            }

            let data = NSKeyedArchiver.archivedData(withRootObject: newValue)
            defaults.set(data, forKey: #function)
        }
    }

    private func fetchChanges() {
        var changedRecords: [CKRecord] = []

        let options = CKFetchRecordZoneChangesOptions()
        options.previousServerChangeToken = privateChangeToken

        let operation = CKFetchRecordZoneChangesOperation(recordZoneIDs: [customZoneID], optionsByRecordZoneID: [customZoneID: options])
        operation.fetchAllChanges = privateChangeToken == nil

        operation.recordZoneFetchCompletionBlock = { [unowned self] _, token, _, _, error in
            if let error = error {
                os_log("Failed to fetch record zone changes: %{public}@",
                       log: self.log,
                       type: .error,
                       String(describing: error))

                error.retryCloudKitOperationIfPossible(self.log) { self.fetchChanges() }
            } else {
                self.privateChangeToken = token
            }
        }

        operation.recordChangedBlock = { changedRecords.append($0) }

        operation.fetchRecordZoneChangesCompletionBlock = { [unowned self] error in
            if let error = error {
                os_log("Failed to fetch record zone changes: %{public}@",
                       log: self.log,
                       type: .error,
                       String(describing: error))

                error.retryCloudKitOperationIfPossible(self.log) { self.fetchChanges() }
            } else {
                os_log("Finished fetching record zone changes", log: self.log, type: .info)
                DispatchQueue.main.async { self.commitServerChangesToDatabase(with: changedRecords) }
            }
        }

        operation.qualityOfService = .userInitiated
        operation.database = privateDatabase

        cloudOperationQueue.addOperation(operation)
    }

    // MARK: - CloudKit to Realm

    private struct RecordTypes {
        static let favorite = "FavoriteSyncObject"
        static let bookmark = "BookmarkSyncObject"
        static let sessionProgress = "SessionProgressSyncObject"
    }

    private var recordTypesToRealmModels: [String: SoftDeletableRealmObjectWithCloudKitFields.Type] = [
        RecordTypes.favorite: Favorite.self,
        RecordTypes.bookmark: Bookmark.self,
        RecordTypes.sessionProgress: SessionProgress.self
    ]

    private var recordTypesToLastSyncDates: [String: Date] = [:]

    private func realmModel(for recordType: String) -> SoftDeletableRealmObjectWithCloudKitFields.Type? {
        return recordTypesToRealmModels[recordType]
    }

    private func performRealmOperations(with block: (Realm) -> Void) {
        storage.realm.beginWrite()

        block(storage.realm)

        do {
            try storage.realm.commitWrite(withoutNotifying: realmNotificationTokens)
        } catch {
            os_log("Failed to perform Realm transaction: %{public}@", log: self.log, type: .error, String(describing: error))
        }
    }

    private func commitServerChangesToDatabase(with records: [CKRecord]) {
        guard records.count > 0 else {
            os_log("Finished record zone changes fetch with no changes", log: log, type: .info)
            return
        }

        os_log("Will commit %{public}d changed record(s) to the database", log: log, type: .info, records.count)

        performRealmOperations { realm in
            records.forEach {
                switch $0.recordType {
                case .favorite:
                    self.commit(objectType: Favorite.self, with: record, in: realm)
                case .bookmark:
                    self.commit(objectType: Bookmark.self, with: record, in: realm)
                case .sessionProgress:
                    self.commit(objectType: SessionProgress.self, with: record, in: realm)
                default:
                    os_log("Unknown record type %{public}@", log: self.log, type: .fault, record.recordType)
                }
            }
        }
    }

    private func commit<T: SynchronizableRealmObject>(objectType: T.Type, with record: CKRecord, in realm: Realm) {
        do {
            let obj = try CloudKitRecordDecoder().decode(objectType.SyncObject.self, from: record)
            let model = objectType.from(syncObject: obj)

            realm.add(model, update: true)

            guard let sessionId = obj.sessionId else {
                os_log("Sync object didn't have a sessionId!", log: self.log, type: .fault)
                return
            }
            guard let session = realm.object(ofType: Session.self, forPrimaryKey: sessionId) else {
                os_log("Failed to find session with identifier: %{public}@ for synced object", log: self.log, type: .error, sessionId)
                return
            }

            session.addChild(object: model)
        } catch {
            os_log("Failed to decode sync object from cloud record: %{public}@",
                   log: self.log,
                   type: .error,
                   String(describing: error))
        }
    }

    // MARK: - Realm to CloudKit

    private var realmNotificationTokens: [NotificationToken] = []

    private func observeLocalChanges() {
        registerRealmObserver(for: Favorite.self)
        registerRealmObserver(for: Bookmark.self)
        registerRealmObserver(for: SessionProgress.self)
    }

    private func registerRealmObserver<T: SynchronizableRealmObject>(for objectType: T.Type) {
        let token = storage.realm.objects(objectType).observe { [unowned self] change in
            switch change {
            case .error(let error):
                os_log("Realm observer error: %{public}@",
                       log: self.log,
                       type: .error,
                       String(describing: error))
            case let .update(objects, _, inserted, modified):
                let objectsToUpload = inserted.map { objects[$0] } + modified.map { objects[$0] }
                self.upload(models: objectsToUpload)
            default:
                break
            }
        }

        realmNotificationTokens.append(token)
    }

    private func upload<T: SynchronizableRealmObject>(models: [T]) {
        guard models.count > 0 else { return }

        os_log("Upload models. Count = %{public}d", log: log, type: .info, models.count)

        let syncObjects = models.compactMap { $0.syncObject }

        let records = syncObjects.compactMap { try? CloudKitRecordEncoder(zoneID: customZoneID).encode($0) }

        os_log("Produced %{public}d record(s) for %{public}d model(s)", log: log, type: .info, records.count, models.count)

        upload(records)
    }

    private func upload(_ records: [CKRecord]) {
        guard let firstRecord = records.first else { return }

        guard let objectType = realmModel(for: firstRecord.recordType) else {
            os_log("Refusing to upload record of unknown type: %{public}@",
                   log: self.log,
                   type: .error,
                   firstRecord.recordType)
            return
        }

        if let lastSyncDate = recordTypesToLastSyncDates[firstRecord.recordType] {
            guard Date().timeIntervalSince(lastSyncDate) > objectType.syncThrottlingInterval else {
                os_log("Throttled. Interval for %{public}@ is %{public}f seconds",
                       log: log,
                       type: .debug,
                       firstRecord.recordType,
                       objectType.syncThrottlingInterval)
                return
            }
        }
        recordTypesToLastSyncDates[firstRecord.recordType] = Date()

        let operation = CKModifyRecordsOperation(recordsToSave: records, recordIDsToDelete: nil)

        operation.perRecordCompletionBlock = { [unowned self] record, error in
            // We're only interested in conflict errors here
            guard let error = error, error.isCloudKitConflict else { return }

            os_log("CloudKit conflict with record of type %{public}@", log: self.log, type: .error, record.recordType)

            guard let objectType = self.realmModel(for: record.recordType) else {
                os_log(
                    "No object type registered for record type: %{public}@. This should never happen!",
                    log: self.log,
                    type: .fault,
                    record.recordType
                )
                return
            }

            guard let resolvedRecord = error.resolveConflict(with: objectType.resolveConflict) else {
                os_log(
                    "Resolving conflict with record of type %{public}@ returned a nil record. Giving up.",
                    log: self.log,
                    type: .error,
                    record.recordType
                )
                return
            }

            os_log("Conflict resolved, will retry upload", log: self.log, type: .info)

            self.upload([resolvedRecord])
        }

        operation.modifyRecordsCompletionBlock = { [unowned self] serverRecords, _, error in
            if let error = error {
                os_log("Failed to upload records: %{public}@", log: self.log, type: .error, String(describing: error))
                error.retryCloudKitOperationIfPossible(self.log) { self.upload(records) }
            } else {
                os_log("Successfully uploaded %{public}d record(s)", log: self.log, type: .info, records.count)

                DispatchQueue.main.async {
                    guard let serverRecords = serverRecords else { return }
                    self.updateDatabaseModelsSystemFieldsAfterUpload(with: serverRecords)
                }
            }
        }

        operation.savePolicy = .changedKeys
        operation.qualityOfService = .userInitiated
        operation.database = privateDatabase

        cloudOperationQueue.addOperation(operation)
    }

    private func updateDatabaseModelsSystemFieldsAfterUpload(with records: [CKRecord]) {
        performRealmOperations { realm in
            records.forEach { record in
                guard let modelType = realmModel(for: record.recordType) else {
                    os_log("There's no corresponding Realm model type for record type %{public}@",
                           log: log,
                           type: .error,
                           record.recordType)
                    return
                }

                guard var object = realm.object(ofType: modelType, forPrimaryKey: record.recordID.recordName) as? HasCloudKitFields else {
                    os_log("Unable to find record type %{public}@ with primary key %{public}@ for update after sync upload",
                           log: log,
                           type: .error,
                           record.recordType,
                           record.recordID.recordName)
                    return
                }

                object.ckFields = record.encodedSystemFields

                os_log("Updated ckFields in record of type %{public}@", log: log, type: .debug, record.recordType)
            }
        }
    }

    // MARK: Initial data upload

    private func uploadLocalDataNotUploadedYet() {
        uploadLocalModelsNotUploadedYet(of: Favorite.self)
        uploadLocalModelsNotUploadedYet(of: Bookmark.self)
        uploadLocalModelsNotUploadedYet(of: SessionProgress.self)
    }

    private func uploadLocalModelsNotUploadedYet<T: SynchronizableRealmObject>(of objectType: T.Type) {
        let objects = storage.realm.objects(objectType).toArray().filter({ $0.ckFields.count == 0 && !$0.isDeleted })

        upload(models: objects)
    }

    // MARK: - Deletion

    private func incinerateSoftDeletedObjects() {
        let predicate = NSPredicate(format: "isDeleted == true")
        let deletedFavorites = storage.realm.objects(Favorite.self).filter(predicate)
        let deletedBookmarks = storage.realm.objects(Bookmark.self).filter(predicate)

        os_log("Will incinerate %{public}d deleted object(s)", log: log, type: .info, deletedFavorites.count + deletedBookmarks.count)

        let favoriteIDs: [CKRecordID] = deletedFavorites.compactMap { $0.ckRecordID }
        let bookmarkIDs: [CKRecordID] = deletedBookmarks.compactMap { $0.ckRecordID }
        let recordsToIncinerate = favoriteIDs + bookmarkIDs

        let operation = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: recordsToIncinerate)

        operation.modifyRecordsCompletionBlock = { [unowned self] _, _, error in
            if let error = error {
                os_log("Failed to incinerate records: %{public}@",
                       log: self.log,
                       type: .error,
                       String(describing: error))

                error.retryCloudKitOperationIfPossible(self.log) { self.incinerateSoftDeletedObjects() }
            } else {
                os_log("Successfully incinerated %{public}d record(s)",
                       log: self.log,
                       type: .info,
                       recordsToIncinerate.count)

                DispatchQueue.main.async {
                    // Actually delete previously soft-deleted items from the database
                    self.performRealmOperations { realm in
                        deletedFavorites.forEach(realm.delete)
                        deletedBookmarks.forEach(realm.delete)
                    }
                }
            }
        }

        operation.database = privateDatabase
        operation.qualityOfService = .userInitiated

        cloudOperationQueue.addOperation(operation)
    }

}
#endif
