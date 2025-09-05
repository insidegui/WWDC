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
import Combine
import struct OSLog.Logger

@MainActor
public final class UserDataSyncEngine: Logging {

    public init(storage: Storage, container: CKContainer = .default()) {
        self.storage = storage
        self.defaults = .standard
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

    public static let log = makeLogger()

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

    private lazy var customZoneID: CKRecordZone.ID = {
        return CKRecordZone.ID(zoneName: Constants.zoneName, ownerName: CKCurrentUserDefaultName)
    }()

    // MARK: - State management

    public private(set) var isRunning = false

    private var isWaitingForAccountAvailabilityToStart = false

    @MainActor
    public var isEnabled = false {
        didSet {
            guard oldValue != isEnabled else { return }

            /// Prevents `isEnabled` from causing start before `start()` has been called at least once.
            guard canStart else { return }

            if isEnabled {
                log.debug("Starting because isEnabled has changed to true")
                start()
            } else {
                isWaitingForAccountAvailabilityToStart = false
                log.debug("Stopping because isEnabled has changed to false")
                stop()
            }
        }
    }

    private lazy var cancellables: Set<AnyCancellable> = []

    private var canStart = false

    @MainActor
    public func start() {
        canStart = true

        guard ConfCoreCapabilities.isCloudKitEnabled else { return }

        guard !isWaitingForAccountAvailabilityToStart else { return }
        guard isEnabled else { return }

        guard !isRunning else { return }

        log.debug("Start!")

        // Only start the sync engine if there's an iCloud account available, if availability is not
        // determined yet, start the sync engine after the account availability is known and == available

        guard isAccountAvailable else {
            log.info("iCloud account is not available yet, waiting for availability to start")
            isWaitingForAccountAvailabilityToStart = true

            $isAccountAvailable.receive(on: DispatchQueue.main).sink(receiveValue: { [unowned self] available in
                guard self.isWaitingForAccountAvailabilityToStart else { return }

                log.info("iCloud account available = \(String(describing: available), privacy: .public)@")

                if available {
                    self.isWaitingForAccountAvailabilityToStart = false
                    self.start()
                }
            }).store(in: &cancellables)

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
    }

    @Published public private(set) var isStopping = false

    @Published public private(set) var isPerformingSyncOperation = false

    @Published public private(set) var isAccountAvailable = false

    public func stop() {
        guard isRunning, !isStopping else {
            self.clearSyncMetadata()
            return
        }
        
        isStopping = true

        workQueue.async { [unowned self, cloudOperationQueue] in
            defer {
                Task { @MainActor in
                    self.isStopping = false
                    self.isRunning = false
                }
            }

            cloudOperationQueue.waitUntilAllOperationsAreFinished()

            DispatchQueue.main.async {
                self.stopObservingSyncOperations()

                self.realmNotificationTokens.forEach { $0.invalidate() }
                self.realmNotificationTokens.removeAll()

                self.clearSyncMetadata()
            }
        }
    }

    private var cloudQueueObservation: NSKeyValueObservation?

    private func startObservingSyncOperations() {
        cloudQueueObservation = cloudOperationQueue.observe(\.operationCount) { [unowned self] queue, _ in
            self.isPerformingSyncOperation = queue.operationCount > 0
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

        log.debug("checkAccountAvailability()")

        container.accountStatus { [unowned self] status, error in
            defer { self.isWaitingForAccountAvailabilityReply = false }

            if let error = error {
                log.error("Failed to determine iCloud account status: \(String(describing: error), privacy: .public)@")
                return
            }

            log.debug("iCloud availability status is \(status.rawValue, privacy: .public)")

            switch status {
            case .available:
                self.isAccountAvailable = true
            default:
                self.isAccountAvailable = false
            }
        }
    }

    // MARK: - Cloud environment management

    private func prepareCloudEnvironment(then block: @MainActor @escaping () -> Void) {
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

    private func createCustomZoneIfNeeded(then completion: (() -> Void)? = nil) {
        guard !createdCustomZone else {
            log.debug("Already have custom zone, skipping creation")
            return
        }

        log.info("Creating CloudKit zone \(Constants.zoneName)")

        let zone = CKRecordZone(zoneID: customZoneID)
        let operation = CKModifyRecordZonesOperation(recordZonesToSave: [zone], recordZoneIDsToDelete: nil)

        operation.modifyRecordZonesCompletionBlock = { [unowned self] _, _, error in
            if let error = error {
                log.error("Failed to create custom CloudKit zone: \(String(describing: error), privacy: .public)@")

                error.retryCloudKitOperationIfPossible(self.log) { self.createCustomZoneIfNeeded() }
            } else {
                log.info("Zone created successfully")
                self.createdCustomZone = true

                DispatchQueue.main.async { completion?() }
            }
        }

        operation.qualityOfService = .userInitiated
        operation.database = privateDatabase

        cloudOperationQueue.addOperation(operation)
    }

    private func createPrivateSubscriptionsIfNeeded() {
        guard !createdPrivateSubscription else {
            log.debug("Already subscribed to private database changes, skipping subscription")
            return
        }

        let subscription = CKDatabaseSubscription(subscriptionID: Constants.privateSubscriptionId)

        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        subscription.notificationInfo = notificationInfo

        let operation = CKModifySubscriptionsOperation(subscriptionsToSave: [subscription], subscriptionIDsToDelete: nil)

        operation.modifySubscriptionsCompletionBlock = { [unowned self] _, _, error in
            if let error = error {
                log.error("Failed to create private CloudKit subscription: \(String(describing: error), privacy: .public)")

                error.retryCloudKitOperationIfPossible(self.log) { self.createPrivateSubscriptionsIfNeeded() }
            } else {
                log.info("Private subscription created successfully")
                self.createdPrivateSubscription = true
            }
        }

        operation.database = privateDatabase
        operation.qualityOfService = .utility

        cloudOperationQueue.addOperation(operation)
    }

    func clearSyncMetadata() {
        log.debug("\(#function, privacy: .public)")
        
        privateChangeToken = nil
        createdPrivateSubscription = false
        createdCustomZone = false
        tombstoneRecords.removeAll()

        clearCloudKitFields()
    }

    private func clearCloudKitFields() {
        clearCloudKitFields(for: Favorite.self)
        clearCloudKitFields(for: SessionProgress.self)
        clearCloudKitFields(for: Bookmark.self)
    }

    private func clearCloudKitFields<T: SynchronizableObject>(for objectType: T.Type) {
        performRealmOperations { realm in
            realm.objects(objectType).forEach { model in
                var mutableModel = model
                mutableModel.ckFields = Data()
            }
        }
    }

    // MARK: - Silent notifications

    @MainActor
    public func processSubscriptionNotification(with userInfo: [String: Any]) -> Bool {
        guard isEnabled, isRunning else { return false }

        let notification = CKNotification(fromRemoteNotificationDictionary: userInfo)

        guard notification?.subscriptionID == Constants.privateSubscriptionId else { return false }

        log.debug("Received remote CloudKit notification for user data")

        fetchChanges()

        return true
    }

    // MARK: - Data syncing

    private func fetchChanges() {
        var changedRecords: [CKRecord] = []

        let operation = CKFetchRecordZoneChangesOperation()

        let config = CKFetchRecordZoneChangesOperation.ZoneConfiguration(
            previousServerChangeToken: privateChangeToken,
            resultsLimit: nil,
            desiredKeys: nil
        )

        operation.recordZoneIDs = [customZoneID]
        operation.fetchAllChanges = privateChangeToken == nil
        operation.configurationsByRecordZoneID = [customZoneID: config]

        operation.recordZoneFetchCompletionBlock = { [unowned self] _, token, _, _, error in
            if let error = error {
                log.error("Failed to fetch record zone changes: \(String(describing: error), privacy: .public)")

                if error.isCKTokenExpired {
                    log.error("Change token expired, clearing token and retrying")

                    DispatchQueue.main.async {
                        self.privateChangeToken = nil
                        self.fetchChanges()
                    }
                    return
                } else if error.isCKZoneDeleted {
                    log.error("User deleted CK zone, recreating")

                    DispatchQueue.main.async {
                        self.privateChangeToken = nil
                        self.createdCustomZone = false

                        self.createCustomZoneIfNeeded {
                            self.clearCloudKitFields()
                            self.uploadLocalDataNotUploadedYet()
                            self.fetchChanges()
                        }
                    }
                    return
                } else {
                    error.retryCloudKitOperationIfPossible(self.log) { self.fetchChanges() }
                }
            } else {
                self.privateChangeToken = token
            }
        }

        operation.recordChangedBlock = { changedRecords.append($0) }

        operation.fetchRecordZoneChangesCompletionBlock = { [unowned self] error in
            guard error == nil else { return }

            log.info("Finished fetching record zone changes")
            self.databaseQueue.async { self.commitServerChangesToDatabase(with: changedRecords) }
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

    private var recordTypesToRealmModels: [String: SoftDeletableSynchronizableObject.Type] = [
        RecordTypes.favorite: Favorite.self,
        RecordTypes.bookmark: Bookmark.self,
        RecordTypes.sessionProgress: SessionProgress.self
    ]

    private var recordTypesToLastSyncDates: [String: Date] = [:]

    private func realmModel(for recordType: String) -> SoftDeletableSynchronizableObject.Type? {
        return recordTypesToRealmModels[recordType]
    }

    private func performRealmOperations(with block: @escaping (Realm) -> Void) {
        databaseQueue.async {
            self.onQueuePerformRealmOperations(with: block)
        }
    }

    private func onQueuePerformRealmOperations(with block: @escaping (Realm) -> Void) {
        guard let realm = backgroundRealm else { fatalError("Missing background Realm") }

        do {
            realm.beginWrite()

            block(realm)

            try realm.commitWrite(withoutNotifying: realmNotificationTokens)
        } catch {
            log.error("Failed to perform Realm transaction: \(String(describing: error), privacy: .public)")
        }
    }

    private static let privateChangeTokenDefaultsKey = "privateChangeToken"
    private static let tombstoneRecordsDefaultsKey = "tombstoneRecords"

    public static func resetLocalMetadata() {
        UserDefaults.standard.removeObject(forKey: Self.privateChangeTokenDefaultsKey)
        UserDefaults.standard.removeObject(forKey: Self.tombstoneRecordsDefaultsKey)
        UserDefaults.standard.synchronize()
    }

    /// Record tombstone keys for sync objects that are known to no longer have valid content associated with them.
    private var tombstoneRecords: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: Self.tombstoneRecordsDefaultsKey) ?? []) }
        set {
            UserDefaults.standard.set(Array(newValue), forKey: Self.tombstoneRecordsDefaultsKey)
            UserDefaults.standard.synchronize()
        }
    }

    private var privateChangeToken: CKServerChangeToken? {
        get {
            guard let data = defaults.data(forKey: Self.privateChangeTokenDefaultsKey) else { return nil }

            do {
                guard let token = try NSKeyedUnarchiver.unarchivedObject(ofClass: CKServerChangeToken.self, from: data) else {
                    log.error("Failed to decode CKServerChangeToken from defaults key privateChangeToken")
                    return nil
                }

                return token
            } catch {
                log.fault("Failed to decode CKServerChangeToken from defaults key privateChangeToken: \(String(describing: error), privacy: .public)")
                return nil
            }
        }
        set {
            guard let newValue = newValue else {
                defaults.removeObject(forKey: Self.privateChangeTokenDefaultsKey)
                return
            }

            let data = NSKeyedArchiver.archiveData(with: newValue, secure: true)
            defaults.set(data, forKey: Self.privateChangeTokenDefaultsKey)
        }
    }

    private var recordsPendingContentSync = Set<CKRecord>()

    private func commitServerChangesToDatabase(with records: [CKRecord], shouldRetryAfterContentSync: Bool = true) {
        guard records.count > 0 else {
            log.info("Finished record zone changes fetch with no changes")
            return
        }

        log.info("Will commit \(records.count, privacy: .public) changed record(s) to the database")

        performRealmOperations { [weak self] queueRealm in
            guard let self = self else { return }

            let pendingRecords: [CKRecord] = records.compactMap { pendingRecord in
                let result: CommitResult

                switch pendingRecord.recordType {
                case RecordTypes.favorite:
                    result = self.commit(objectType: Favorite.self, with: pendingRecord, in: queueRealm)
                case RecordTypes.bookmark:
                    result = self.commit(objectType: Bookmark.self, with: pendingRecord, in: queueRealm)
                case RecordTypes.sessionProgress:
                    result = self.commit(objectType: SessionProgress.self, with: pendingRecord, in: queueRealm)
                default:
                    self.log.fault("Unknown record type \(pendingRecord.recordType, privacy: .public)")
                    return nil
                }

                guard result == .pendingContent else {
                    self.removeFromPending(pendingRecord)
                    return nil
                }

                /// Record is pending content sync.
                return pendingRecord
            }

            if pendingRecords.isEmpty {
                log.debug("Finished commit Realm operations")
            } else {
                if shouldRetryAfterContentSync {
                    let validPendingRecords = pendingRecords.filter({ !self.tombstoneRecords.contains($0.tombstoneKey) })

                    log.debug("Finished commit Realm operations with \(validPendingRecords.count, privacy: .public) record(s) pending content sync")

                    self.workQueue.async {
                        self.recordsPendingContentSync.formUnion(validPendingRecords)
                    }
                } else {
                    log.debug("Invalidating \(pendingRecords.count, privacy: .public) sync objects for no longer having valid content associated with them")

                    self.tombstoneRecords.formUnion(pendingRecords.map(\.tombstoneKey))
                }
            }
        }
    }

    private func removeFromPending(_ record: CKRecord) {
        workQueue.async { [weak self] in
            guard let self = self else { return }

            guard let pendingRecord = self.recordsPendingContentSync.first(where: { $0.recordID == record.recordID }) else { return }
            self.recordsPendingContentSync.remove(pendingRecord)
        }
    }

    /// Attempts to ingest remote records into the local database which were pending the availability of local content.
    func commitRecordsPendingContentSyncIfNeeded() {
        workQueue.async { [weak self] in
            guard let self = self else { return }

            guard !self.recordsPendingContentSync.isEmpty else { return }

            log.debug("Will commit \(self.recordsPendingContentSync.count, privacy: .public) record(s) pending content sync")

            let snapshot = self.recordsPendingContentSync

            self.recordsPendingContentSync.removeAll()

            self.commitServerChangesToDatabase(with: Array(snapshot), shouldRetryAfterContentSync: false)
        }
    }

    private enum CommitResult {
        case pendingContent
        case failure
        case success
    }

    private func commit<T: SynchronizableObject>(objectType: T.Type, with record: CKRecord, in realm: Realm) -> CommitResult {
        do {
            let obj = try CloudKitRecordDecoder().decode(objectType.SyncObject.self, from: record)
            let model = objectType.from(syncObject: obj)

            realm.add(model, update: .all)

            guard let sessionId = obj.sessionId else {
                log.fault("Sync object didn't have a sessionId!")
                return .failure
            }
            guard let session = realm.object(ofType: Session.self, forPrimaryKey: sessionId) else {
                log.info("No session #\(sessionId, privacy: .public) for \(record.recordType, privacy: .public) object")
                return .pendingContent
            }

            session.addChild(object: model)

            return .success
        } catch {
            log.error("Failed to decode sync object from cloud record: \(String(describing: error), privacy: .public)")
            return .failure
        }
    }

    // MARK: - Realm to CloudKit

    private var realmNotificationTokens: [NotificationToken] = []

    private func observeLocalChanges() {
        openBackgroundRealm {
            self.registerRealmObserver(for: Favorite.self)
            self.registerRealmObserver(for: Bookmark.self)
            self.registerRealmObserver(for: SessionProgress.self)
        }
    }

    private let databaseQueue = DispatchQueue(label: "Database", qos: .background)
    private var backgroundRealm: Realm?

    private func openBackgroundRealm(completion: @escaping () -> Void) {
        Realm.asyncOpen(configuration: storage.realm.configuration, callbackQueue: databaseQueue) { result in
            switch result {
            case .failure(let error):
                self.log.fault("Failed to open background Realm for sync operations: \(String(describing: error), privacy: .public)")
            case .success(let realm):
                self.backgroundRealm = realm
                DispatchQueue.main.async { completion() }
            }
        }
    }

    private func registerRealmObserver<T: SynchronizableObject>(for objectType: T.Type) {
        databaseQueue.async {
            do {
                try self.onQueueRegisterRealmObserver(for: objectType)
            } catch {
                self.log.error("Failed to register notification: \(String(describing: error), privacy: .public)")
            }
        }
    }

    private func onQueueRegisterRealmObserver<T: SynchronizableObject>(for objectType: T.Type) throws {
        guard let realm = backgroundRealm else { return }

        let token = realm.objects(objectType).observe { [unowned self] change in
            switch change {
            case .error(let error):
                log.error("Realm observer error: \(String(describing: error), privacy: .public)")
            case .update(let objects, _, let inserted, let modified):
                let objectsToUpload = inserted.map { objects[$0] } + modified.map { objects[$0] }
                self.upload(models: objectsToUpload)
            default:
                break
            }
        }

        realmNotificationTokens.append(token)
    }

    private func upload<T: SynchronizableObject>(models: [T]) {
        guard models.count > 0 else { return }

        log.info("Upload models. Count = \(models.count, privacy: .public)")

        let syncObjects = models.compactMap { $0.syncObject }

        let records = syncObjects.compactMap { try? CloudKitRecordEncoder(zoneID: customZoneID).encode($0) }

        log.info("Produced \(records.count, privacy: .public) record(s) for \(models.count, privacy: .public) model(s)")

        upload(records)
    }

    private func upload(_ records: [CKRecord]) {
        guard let firstRecord = records.first else { return }

        guard let objectType = realmModel(for: firstRecord.recordType) else {
            log.error("Refusing to upload record of unknown type: \(firstRecord.recordType, privacy: .public)")
            return
        }

        if let lastSyncDate = recordTypesToLastSyncDates[firstRecord.recordType] {
            guard Date().timeIntervalSince(lastSyncDate) > objectType.syncThrottlingInterval else {
                return
            }
        }
        recordTypesToLastSyncDates[firstRecord.recordType] = Date()

        let operation = CKModifyRecordsOperation(recordsToSave: records, recordIDsToDelete: nil)

        operation.perRecordCompletionBlock = { [unowned self] record, error in
            // We're only interested in conflict errors here
            guard let error = error, error.isCloudKitConflict else { return }

            log.error("CloudKit conflict with record of type \(record.recordType, privacy: .public)")

            guard let objectType = self.realmModel(for: record.recordType) else {
                log.fault(
                    "No object type registered for record type: \(record.recordType, privacy: .public). This should never happen!"
                )
                return
            }

            guard let resolvedRecord = error.resolveConflict(with: objectType.resolveConflict) else {
                log.error(
                    "Resolving conflict with record of type \(record.recordType, privacy: .public)@ returned a nil record. Giving up."
                )
                return
            }

            log.info("Conflict resolved, will retry upload")

            self.upload([resolvedRecord])
        }

        operation.modifyRecordsCompletionBlock = { [unowned self] serverRecords, _, error in
            if let error = error {
                log.error("Failed to upload records: \(String(describing: error), privacy: .public)")
                error.retryCloudKitOperationIfPossible(self.log) { self.upload(records) }
            } else {
                log.info("Successfully uploaded \(records.count, privacy: .public) record(s)")

                self.databaseQueue.async {
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
        performRealmOperations { [weak self] realm in
            guard let self = self else { return }

            records.forEach { record in
                guard let modelType = self.realmModel(for: record.recordType) else {
                    self.log.error("There's no corresponding Realm model type for record type \(record.recordType, privacy: .public)")
                    return
                }

                guard var object = realm.object(ofType: modelType, forPrimaryKey: record.recordID.recordName) as? HasCloudKitFields else {
                    self.log.error("Unable to find record type \(record.recordType, privacy: .public)@ with primary key \(record.recordID.recordName, privacy: .public) for update after sync upload")
                    return
                }

                object.ckFields = record.encodedSystemFields

                self.log.debug("Updated ckFields in record of type \(record.recordType, privacy: .public)")
            }
        }
    }

    // MARK: Initial data upload

    private func uploadLocalDataNotUploadedYet() {
        log.debug("\(#function, privacy: .public)")

        uploadLocalModelsNotUploadedYet(of: Favorite.self)
        uploadLocalModelsNotUploadedYet(of: Bookmark.self)
        uploadLocalModelsNotUploadedYet(of: SessionProgress.self)
    }

    private func uploadLocalModelsNotUploadedYet<T: SynchronizableObject>(of objectType: T.Type) {
        databaseQueue.async {
            guard let objects = self.backgroundRealm?.objects(objectType).toArray() else { return }

            self.upload(models: objects.filter({ $0.ckFields.count == 0 && !$0.isDeleted }))
        }
    }

    // MARK: - Deletion

    private func incinerateSoftDeletedObjects() {
        databaseQueue.async {
            self.onQueueIncinerateSoftDeletedObjects()
        }
    }

    private func onQueueIncinerateSoftDeletedObjects() {
        guard let realm = backgroundRealm else { return }

        let predicate = NSPredicate(format: "isDeleted == true")
        let deletedFavorites = realm.objects(Favorite.self).filter(predicate)
        let deletedBookmarks = realm.objects(Bookmark.self).filter(predicate)

        let deletedFavoriteObjIDs = deletedFavorites.toArray().map(\.identifier)
        let deletedBookmarkObjIDs = deletedBookmarks.toArray().map(\.identifier)

        log.info("Will incinerate \(deletedFavorites.count + deletedBookmarks.count, privacy: .public)d deleted object(s)")

        let favoriteIDs: [CKRecord.ID] = deletedFavorites.compactMap { $0.ckRecordID }
        let bookmarkIDs: [CKRecord.ID] = deletedBookmarks.compactMap { $0.ckRecordID }
        let recordsToIncinerate = favoriteIDs + bookmarkIDs

        let operation = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: recordsToIncinerate)

        operation.modifyRecordsCompletionBlock = { [unowned self] _, _, error in
            if let error = error {
                log.error("Failed to incinerate records: \(String(describing: error), privacy: .public)")

                error.retryCloudKitOperationIfPossible(self.log, in: self.databaseQueue) { self.incinerateSoftDeletedObjects() }
            } else {
                log.info("Successfully incinerated \(recordsToIncinerate.count, privacy: .public) record(s)")

                DispatchQueue.main.async {
                    // Actually delete previously soft-deleted items from the database
                    self.performRealmOperations { queueRealm in
                        let favoriteObjs = deletedFavoriteObjIDs.compactMap { queueRealm.object(ofType: Favorite.self, forPrimaryKey: $0) }
                        let bookmarkObjs = deletedBookmarkObjIDs.compactMap { queueRealm.object(ofType: Bookmark.self, forPrimaryKey: $0) }

                        favoriteObjs.forEach(queueRealm.delete)
                        bookmarkObjs.forEach(queueRealm.delete)
                    }
                }
            }
        }

        operation.database = privateDatabase
        operation.qualityOfService = .userInitiated

        cloudOperationQueue.addOperation(operation)
    }

}

extension Error {
    var isCKTokenExpired: Bool { (self as? CKError)?.code == .changeTokenExpired }
    var isCKZoneDeleted: Bool { (self as? CKError)?.code == .userDeletedZone }
}

private extension CKRecord {
    var tombstoneKey: String { "\(recordID.zoneID.ownerName)-\(recordID.zoneID.zoneName)-\(recordType)-\(recordID.recordName)" }
}
