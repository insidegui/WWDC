//
//  Storage.swift
//  WWDC
//
//  Created by Guilherme Rambo on 17/03/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Foundation
import RealmSwift
import RxSwift
import RxRealm
import RxCocoa

public final class Storage {

    public let realmConfig: Realm.Configuration
    public let realm: Realm

    let disposeBag = DisposeBag()

    public init(_ configuration: Realm.Configuration) throws {
        var config = configuration

        config.migrationBlock = Storage.migrate(migration:oldVersion:)

        realmConfig = config

        realm = try Realm(configuration: config)

        DistributedNotificationCenter.default().rx.notification(.TranscriptIndexingDidStart).subscribe(onNext: { [unowned self] _ in
            #if DEBUG
                NSLog("[Storage] Locking realm autoupdates until transcript indexing is finished")
            #endif

            self.realm.autorefresh = false
        }).disposed(by: disposeBag)

        DistributedNotificationCenter.default().rx.notification(.TranscriptIndexingDidStop).subscribe(onNext: { [unowned self] _ in
            #if DEBUG
                NSLog("[Storage] Realm autoupdates unlocked")
            #endif

            self.realm.autorefresh = true
        }).disposed(by: disposeBag)

        deleteOldEventsIfNeeded()
    }

    private func makeRealm() throws -> Realm {
        return try Realm(configuration: realmConfig)
    }

    public lazy var storageQueue: OperationQueue = {
        let q = OperationQueue()

        q.name = "WWDC Storage"
        q.maxConcurrentOperationCount = 1
        q.underlyingQueue = DispatchQueue(label: "WWDC Storage", qos: .background)

        return q
    }()

    private func deleteOldEventsIfNeeded() {
        guard let wwdc2012 = realm.objects(Event.self).filter("identifier == %@", "wwdc2012").first else { return }

        do {
            try realm.write {
                realm.delete(wwdc2012.sessions)
                realm.delete(wwdc2012)
            }
        } catch {
            NSLog("Error deleting old events: \(error)")
        }
    }

    internal static func migrate(migration: Migration, oldVersion: UInt64) {
        let migrator = StorageMigrator(migration: migration, oldVersion: oldVersion)

        migrator.perform()
    }

    func store(contentResult: Result<ContentsResponse, APIError>, completion: @escaping (Error?) -> Void) {
        if case let .error(error) = contentResult {
            NSLog("Error downloading sessions: \(error)")
            completion(error)
            return
        }

        guard case let .success(sessionsResponse) = contentResult else {
            return
        }

        performSerializedBackgroundWrite(writeBlock: { backgroundRealm in
            sessionsResponse.sessions.forEach { newSession in
                // Replace any "unknown" resources with their full data
                newSession.related.filter({$0.type == RelatedResourceType.unknown.rawValue}).forEach { unknownResource in
                    if let fullResource = sessionsResponse.resources.filter({$0.identifier == unknownResource.identifier}).first {
                        newSession.related.replace(index: newSession.related.index(of: unknownResource)!, object: fullResource)
                    }
                }

                // Merge existing session data, preserving user-defined data
                if let existingSession = backgroundRealm.object(ofType: Session.self, forPrimaryKey: newSession.identifier) {
                    existingSession.merge(with: newSession, in: backgroundRealm)
                } else {
                    backgroundRealm.add(newSession, update: true)
                }
            }

            // Merge existing instance data, preserving user-defined data
            sessionsResponse.instances.forEach { newInstance in
                if let existingInstance = backgroundRealm.object(ofType: SessionInstance.self, forPrimaryKey: newInstance.identifier) {
                    existingInstance.merge(with: newInstance, in: backgroundRealm)
                } else {
                    // This handles the case where an existing session (which might have user data associated with it) is added to an instance,
                    // it shouldn't happen in the wild but since we goofed up the year/identifier thing and caused an empty schedule view in 2018,
                    // we have to make sure we handle this edge case
                    if let newSession = newInstance.session, let existingSession = backgroundRealm.object(ofType: Session.self, forPrimaryKey: newSession.identifier) {
                        existingSession.merge(with: newSession, in: backgroundRealm)
                        newInstance.session = existingSession
                    }

                    backgroundRealm.add(newInstance, update: true)
                }
            }

            // Save everything
            backgroundRealm.add(sessionsResponse.rooms, update: true)
            backgroundRealm.add(sessionsResponse.tracks, update: true)
            backgroundRealm.add(sessionsResponse.events, update: true)
            backgroundRealm.add(sessionsResponse.resources, update: true)

            // add instances to rooms
            backgroundRealm.objects(Room.self).forEach { room in
                let instances = backgroundRealm.objects(SessionInstance.self).filter("roomIdentifier == %@", room.identifier)

                instances.forEach({ $0.roomName = room.name })

                room.instances.removeAll()
                room.instances.append(objectsIn: instances)
            }

            // add instances and sessions to events
            backgroundRealm.objects(Event.self).forEach { event in
                let instances = backgroundRealm.objects(SessionInstance.self).filter("eventIdentifier == %@", event.identifier)
                let sessions = backgroundRealm.objects(Session.self).filter("eventIdentifier == %@", event.identifier)

                event.sessionInstances.removeAll()
                event.sessionInstances.append(objectsIn: instances)

                event.sessions.removeAll()
                event.sessions.append(objectsIn: sessions)
            }

            // add instances and sessions to tracks
            backgroundRealm.objects(Track.self).forEach { track in
                let instances = backgroundRealm.objects(SessionInstance.self).filter("trackIdentifier == %@", track.identifier)
                let sessions = backgroundRealm.objects(Session.self).filter("trackIdentifier == %@", track.identifier)

                track.instances.removeAll()
                track.instances.append(objectsIn: instances)

                track.sessions.removeAll()
                track.sessions.append(objectsIn: sessions)

                sessions.forEach({ $0.trackName = track.name })
                instances.forEach { instance in
                    instance.trackName = track.name
                    instance.session?.trackName = track.name
                }
            }

            // add live video assets to sessions
            backgroundRealm.objects(SessionAsset.self).filter("rawAssetType == %@", SessionAssetType.liveStreamVideo.rawValue).forEach { liveAsset in
                if let session = backgroundRealm.objects(Session.self).filter("ANY event.year == %d AND number == %@", liveAsset.year, liveAsset.sessionId).first {
                    if !session.assets.contains(liveAsset) {
                        session.assets.append(liveAsset)
                    }
                }
            }

            // Associate session resources with Session objects in database
            backgroundRealm.objects(RelatedResource.self).filter("type == %@", RelatedResourceType.session.rawValue).forEach { resource in
                let identifier = resource.identifier.replacingOccurrences(of: "wwdc", with: "")
                if let session = backgroundRealm.object(ofType: Session.self, forPrimaryKey: identifier) {
                    resource.session = session
                } else {
                    print("Expected session to match related activity identifier: \(identifier)")
                }
            }

            // Create schedule view
            backgroundRealm.delete(backgroundRealm.objects(ScheduleSection.self))

            let instances = backgroundRealm.objects(SessionInstance.self).sorted(by: SessionInstance.standardSort)

            var previousStartTime: Date? = nil
            for instance in instances {
                guard instance.startTime != previousStartTime else { continue }

                autoreleasepool {
                    let instancesForSection = instances.filter({ $0.startTime == instance.startTime })

                    let section = ScheduleSection()

                    section.representedDate = instance.startTime
                    section.eventIdentifier = instance.eventIdentifier
                    section.instances.removeAll()
                    section.instances.append(objectsIn: instancesForSection)
                    section.identifier = ScheduleSection.identifierFormatter.string(from: instance.startTime)

                    backgroundRealm.add(section, update: true)

                    previousStartTime = instance.startTime
                }
            }
        }, disableAutorefresh: true, completionBlock: completion)
    }

    internal func store(liveVideosResult: Result<[SessionAsset], APIError>) {
        guard case .success(let assets) = liveVideosResult else { return }

        performSerializedBackgroundWrite(writeBlock: { backgroundRealm in
            assets.forEach { asset in
                asset.identifier = asset.generateIdentifier()

                if let existingAsset = backgroundRealm.objects(SessionAsset.self).filter("identifier == %@", asset.identifier).first {
                    existingAsset.remoteURL = asset.remoteURL
                } else {
                    backgroundRealm.add(asset, update: true)

                    if let session = backgroundRealm.objects(Session.self).filter("ANY event.year == %d AND number == %@", asset.year, asset.sessionId).first {
                        if !session.assets.contains(asset) {
                            session.assets.append(asset)
                        }
                    }
                }
            }
        })
    }

    /// Performs a write transaction in the background
    ///
    /// - Parameters:
    ///   - writeBlock: The block that will modify the database in the background (autoreleasepool is created automatically)
    ///   - disableAutorefresh: Whether to disable autorefresh on the main Realm instance while the write is in progress
    ///   - completionBlock: A block to be called when the operation is completed (called on the main queue)
    private func performSerializedBackgroundWrite(writeBlock: @escaping (Realm) throws -> Void, disableAutorefresh: Bool = false, createTransaction: Bool = true, completionBlock: ((Error?) -> Void)? = nil) {
        if disableAutorefresh { realm.autorefresh = false }

        DispatchQueue.global(qos: .userInitiated).async {
            var storageError: Error?

            self.storageQueue.addOperation { [unowned self] in
                autoreleasepool {
                    do {
                        let backgroundRealm = try self.makeRealm()

                        if createTransaction { backgroundRealm.beginWrite() }

                        try writeBlock(backgroundRealm)

                        if createTransaction { try backgroundRealm.commitWrite() }

                        backgroundRealm.invalidate()
                    } catch {
                        storageError = error
                    }
                }
            }

            self.storageQueue.waitUntilAllOperationsAreFinished()

            DispatchQueue.main.async {
                if disableAutorefresh {
                    self.realm.autorefresh = true
                    self.realm.refresh()
                }

                completionBlock?(storageError)
            }
        }
    }

    public func backgroundUpdate(with block: @escaping (Realm) throws -> Void) {
        performSerializedBackgroundWrite(writeBlock: { backgroundRealm in
            try block(backgroundRealm)
        })
    }

    /// Gives you an opportunity to update `object` on a background queue
    ///
    /// - Parameters:
    ///   - object: The object you want to manipulate in the background
    ///   - writeBlock: A block that modifies your object
    ///
    /// - Attention:
    ///   Since this method must pass your object between threads,
    ///   it is not guaranteed that your writeBlock will be called.
    ///   Your write block is not called if the method fails to transfer your object between threads.
    public func modify<T>(_ object: T, with writeBlock: @escaping (T) -> Void) where T: ThreadConfined {
        let safeObject = ThreadSafeReference(to: object)

        performSerializedBackgroundWrite(writeBlock: { backgroundRealm in
            guard let resolvedObject = backgroundRealm.resolve(safeObject) else { return }

            try backgroundRealm.write {
                writeBlock(resolvedObject)
            }
        }, createTransaction: false)
    }

    /// Gives you an opportunity to update `objects` on a background queue
    ///
    /// - Parameters:
    ///   - objects: An array of objects you want to manipulate in the background
    ///   - writeBlock: A block that modifies your objects
    ///
    /// - Attention:
    ///   Since this method must pass your objects between threads,
    ///   it is not guaranteed that your writeBlock will be called.
    ///   Your write block is not called if any of the objects can't be transfered between threads.
    public func modify<T>(_ objects: [T], with writeBlock: @escaping ([T]) -> Void) where T: ThreadConfined {
        let safeObjects = objects.map { ThreadSafeReference(to: $0) }

        performSerializedBackgroundWrite(writeBlock: { backgroundRealm in
            let resolvedObjects = safeObjects.compactMap { backgroundRealm.resolve($0) }

            guard resolvedObjects.count == safeObjects.count else {
                NSLog("Failed to perform modify in the background. Some objects couldn't be resolved.")
                return
            }

            try backgroundRealm.write {
                writeBlock(resolvedObjects)
            }
        }, createTransaction: false)
    }

    public lazy var events: Observable<Results<Event>> = {
        let eventsSortedByDateDescending = self.realm.objects(Event.self).sorted(byKeyPath: "startDate", ascending: false)

        return Observable.collection(from: eventsSortedByDateDescending)
    }()

    public lazy var sessionsObservable: Observable<Results<Session>> = {
        return Observable.collection(from: self.realm.objects(Session.self))
    }()

    public var sessions: Results<Session> {
        return realm.objects(Session.self).filter("assets.@count > 0")
    }

    public func session(with identifier: String) -> Session? {
        return realm.object(ofType: Session.self, forPrimaryKey: identifier)
    }

    public func createFavorite(for session: Session) {
        modify(session) { bgSession in
            bgSession.favorites.append(Favorite())
        }
    }

    public var isEmpty: Bool {
        return realm.objects(Event.self).isEmpty
    }

    public func removeFavorite(for session: Session) {
        guard let favorite = session.favorites.first else { return }

        modify(favorite) { bgFavorite in
            bgFavorite.realm?.delete(bgFavorite)
        }
    }

    public lazy var eventsObservable: Observable<Results<Event>> = {
        let events = realm.objects(Event.self).sorted(byKeyPath: "startDate", ascending: false)

        return Observable.collection(from: events)
    }()

    public lazy var focusesObservable: Observable<Results<Focus>> = {
        let focuses = realm.objects(Focus.self).sorted(byKeyPath: "name")

        return Observable.collection(from: focuses)
    }()

    public lazy var tracksObservable: Observable<Results<Track>> = {
        let tracks = self.realm.objects(Track.self).sorted(byKeyPath: "order")

        return Observable.collection(from: tracks)
    }()

    public lazy var scheduleObservable: Observable<Results<ScheduleSection>> = {
        let currentEvents = self.realm.objects(Event.self).filter("isCurrent == true")

        return Observable.collection(from: currentEvents).map({ $0.first?.identifier }).flatMap { (identifier: String?) -> Observable<Results<ScheduleSection>> in
            let sections = self.realm.objects(ScheduleSection.self).filter("eventIdentifier == %@", identifier ?? "").sorted(byKeyPath: "representedDate")

            return Observable.collection(from: sections)
        }
    }()

    public func asset(with remoteURL: URL) -> SessionAsset? {
        return realm.objects(SessionAsset.self).filter("remoteURL == %@", remoteURL.absoluteString).first
    }

    public func bookmark(with identifier: String, in inputRealm: Realm? = nil) -> Bookmark? {
        let effectiveRealm = inputRealm ?? realm

        return effectiveRealm.object(ofType: Bookmark.self, forPrimaryKey: identifier)
    }

    public func deleteBookmark(with identifier: String) {
        guard let bookmark = bookmark(with: identifier) else {
            NSLog("DELETE ERROR: Unable to find bookmark with identifier \(identifier)")
            return
        }

        modify(bookmark) { bgBookmark in
            bgBookmark.realm?.delete(bgBookmark)
        }
    }

    public func softDeleteBookmark(with identifier: String) {
        guard let bookmark = bookmark(with: identifier) else {
            NSLog("SOFT DELETE ERROR: Unable to find bookmark with identifier \(identifier)")
            return
        }

        modify(bookmark) { bgBookmark in
            bgBookmark.isDeleted = true
            bgBookmark.deletedAt = Date()
        }
    }

    public func moveBookmark(with identifier: String, to timecode: Double) {
        guard let bookmark = bookmark(with: identifier) else {
            NSLog("MOVE ERROR: Unable to find bookmark with identifier \(identifier)")
            return
        }

        modify(bookmark) { bgBookmark in
            bgBookmark.timecode = timecode
        }
    }

    public func updateDownloadedFlag(_ isDownloaded: Bool, forAssetsAtPaths filePaths: [String]) {
        DispatchQueue.main.async {
            let assets = filePaths.compactMap { self.realm.objects(SessionAsset.self).filter("relativeLocalURL == %@", $0).first }

            self.modify(assets) { bgAssets in
                bgAssets.forEach { bgAsset in
                    bgAsset.session.first?.isDownloaded = isDownloaded
                }
            }
        }
    }

    public var allEvents: [Event] {
        return realm.objects(Event.self).sorted(byKeyPath: "startDate", ascending: false).toArray()
    }

    public var allFocuses: [Focus] {
        return realm.objects(Focus.self).sorted(byKeyPath: "name").toArray()
    }

    public var allTracks: [Track] {
        return realm.objects(Track.self).sorted(byKeyPath: "order").toArray()
    }

}
