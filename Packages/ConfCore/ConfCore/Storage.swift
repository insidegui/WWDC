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
import os.log

public final class Storage {

    public let realmConfig: Realm.Configuration
    public let realm: Realm

    let disposeBag = DisposeBag()
    private static let log = OSLog(subsystem: "ConfCore", category: "Storage")
    private let log = Storage.log

    public init(_ realm: Realm) {
        self.realmConfig = realm.configuration
        self.realm = realm

        DistributedNotificationCenter.default().rx.notification(.TranscriptIndexingDidStart).subscribe(onNext: { [unowned self] _ in
            os_log("Locking Realm auto-updates until transcript indexing is finished", log: self.log, type: .info)

            self.realm.autorefresh = false
        }).disposed(by: disposeBag)

        DistributedNotificationCenter.default().rx.notification(.TranscriptIndexingDidStop).subscribe(onNext: { [unowned self] _ in
            os_log("Realm auto-updates unlocked", log: self.log, type: .info)

            self.realm.autorefresh = true
        }).disposed(by: disposeBag)

        deleteOldEventsIfNeeded()
    }

    // In order to call this with a specific queue, you must already be on the target queue
    public func makeRealm(on queue: DispatchQueue? = nil) throws -> Realm {
        return try Realm(configuration: realmConfig, queue: queue)
    }

    private lazy var dispatchQueue = DispatchQueue(label: "WWDC Storage", qos: .background)

    public lazy var storageQueue: OperationQueue = {
        let q = OperationQueue()

        q.name = "WWDC Storage"
        q.maxConcurrentOperationCount = 1
        q.underlyingQueue = dispatchQueue

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
            os_log("Error deleting old events: %{public}@",
                   log: log,
                   type: .error,
                   String(describing: error))
        }
    }

    public static func migrate(migration: Migration, oldVersion: UInt64) {
        let migrator = StorageMigrator(migration: migration, oldVersion: oldVersion)

        migrator.perform()
    }

    func store(contentResult: Result<ContentsResponse, APIError>, completion: @escaping (Error?) -> Void) {
        let contentsResponse: ContentsResponse
        do {
            contentsResponse = try contentResult.get()
        } catch {
            os_log("Error downloading contents:\n%{public}@",
                   log: log,
                   type: .error,
                   String(describing: error))
            completion(error)
            return
        }

        performSerializedBackgroundWrite(writeBlock: { backgroundRealm in
            contentsResponse.sessions.forEach { newSession in
                // Replace any "unknown" resources with their full data
                newSession.related.filter({$0.type == RelatedResourceType.unknown.rawValue}).forEach { unknownResource in
                    if let fullResource = contentsResponse.resources.filter({$0.identifier == unknownResource.identifier}).first {
                        newSession.related.replace(index: newSession.related.index(of: unknownResource)!, object: fullResource)
                    }
                }

                // Merge existing session data, preserving user-defined data
                if let existingSession = backgroundRealm.object(ofType: Session.self, forPrimaryKey: newSession.identifier) {
                    existingSession.merge(with: newSession, in: backgroundRealm)
                } else {
                    backgroundRealm.add(newSession, update: .all)
                }
            }

            // Merge existing instance data, preserving user-defined data
            contentsResponse.instances.forEach { newInstance in
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

                    backgroundRealm.add(newInstance, update: .all)
                }
            }

            // Save everything
            backgroundRealm.add(contentsResponse.rooms, update: .all)
            backgroundRealm.add(contentsResponse.tracks, update: .all)
            backgroundRealm.add(contentsResponse.events, update: .all)

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
                if let session = backgroundRealm.object(ofType: Session.self, forPrimaryKey: resource.identifier) {
                    resource.session = session
                }
            }

            // Create schedule view
            backgroundRealm.delete(backgroundRealm.objects(ScheduleSection.self))

            let instances = backgroundRealm.objects(SessionInstance.self).sorted(by: SessionInstance.standardSort)

            var previousStartTime: Date?
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

                    backgroundRealm.add(section, update: .all)

                    previousStartTime = instance.startTime
                }
            }
        }, disableAutorefresh: true, completionBlock: completion)
    }

    internal func store(liveVideosResult: Result<[SessionAsset], APIError>) {
        let assets: [SessionAsset]
        do {
            assets = try liveVideosResult.get()
        } catch {
            os_log("Error downloading live videos:\n%{public}@",
                   log: log,
                   type: .error,
                   String(describing: error))
            return
        }

        performSerializedBackgroundWrite(writeBlock: { [weak self] backgroundRealm in
            guard let self = self else { return }

            assets.forEach { asset in
                asset.identifier = asset.generateIdentifier()

                os_log("Registering live asset with year %{public}d and session number %{public}@",
                       log: self.log,
                       type: .info,
                       asset.year,
                       asset.sessionId)

                backgroundRealm.add(asset, update: .all)

                if let session = backgroundRealm.objects(Session.self).filter("identifier == %@", asset.sessionId).first {
                    if !session.assets.contains(asset) {
                        session.assets.append(asset)
                    }
                }
            }
        })
    }

    internal func store(featuredSectionsResult: Result<[FeaturedSection], APIError>, completion: @escaping (Error?) -> Void) {
        let sections: [FeaturedSection]
        do {
            sections = try featuredSectionsResult.get()
        } catch {
            os_log("Error downloading featured sections:\n%{public}@",
                   log: log,
                   type: .error,
                   String(describing: error))
            completion(error)
            return
        }

        performSerializedBackgroundWrite(writeBlock: { backgroundRealm in
            let existingSections = backgroundRealm.objects(FeaturedSection.self)
            for section in existingSections {
                section.content.forEach { backgroundRealm.delete($0) }
                section.author.map { backgroundRealm.delete($0) }
                backgroundRealm.delete(section)
            }

            backgroundRealm.add(sections, update: .all)

            // Associate contents with sessions
            sections.forEach { section in
                section.content.forEach { content in
                    content.session = backgroundRealm.object(ofType: Session.self, forPrimaryKey: content.sessionId)
                }
            }
        }, disableAutorefresh: true, completionBlock: completion)
    }

    internal func store(configResult: Result<ConfigResponse, APIError>, completion: @escaping (Error?) -> Void) {
        let response: ConfigResponse

        do {
            response = try configResult.get()
        } catch {
            os_log("Error downloading config:\n%{public}@",
                   log: log,
                   type: .error,
                   String(describing: error))
            completion(error)
            return
        }

        guard let hero = response.eventHero else {
            os_log("Config response didn't contain an event hero", log: self.log, type: .debug)
            return
        }

        performSerializedBackgroundWrite(writeBlock: { backgroundRealm in
            // We currently only care about whatever the latest event hero is.
            let existingHeroData = backgroundRealm.objects(EventHero.self)
            backgroundRealm.delete(existingHeroData)

            backgroundRealm.add(hero, update: .all)
        }, disableAutorefresh: false, completionBlock: completion)
    }

    internal func store(cocoaHubNewsResult result: Result<CocoaHubIndexResponse, APIError>, completion: @escaping (Error?) -> Void) {
        let response: CocoaHubIndexResponse

        do {
            response = try result.get()
        } catch {
            os_log("Error downloading CocoaHub news:\n%{public}@",
                   log: log,
                   type: .error,
                   String(describing: error))
            completion(error)
            return
        }

        performSerializedBackgroundWrite(writeBlock: { backgroundRealm in
            response.tags.forEach { tag in
                backgroundRealm.add(tag, update: .modified)
            }
            response.news.forEach { item in
                item.rawTags.forEach { tagName in
                    guard let tag = response.tags.first(where: { $0.name == tagName }) else { return }

                    item.tags.append(tag)
                }
            }
            
            backgroundRealm.add(response.news, update: .modified)

            response.editions.forEach { edition in
                if let existingEdition = backgroundRealm.object(ofType: CocoaHubEdition.self, forPrimaryKey: edition.id) {
                    existingEdition.merge(with: edition)
                } else {
                    backgroundRealm.add(edition, update: .all)
                }
            }
        }, disableAutorefresh: false, completionBlock: completion)
    }

    internal func store(cocoaHubEditionArticles result: Result<CocoaHubEditionResponse, APIError>, completion: @escaping (Error?) -> Void) {
        let response: CocoaHubEditionResponse

        do {
            response = try result.get()
        } catch {
            os_log("Error downloading CocoaHub edition:\n%{public}@",
                   log: log,
                   type: .error,
                   String(describing: error))
            completion(error)
            return
        }

        let editionId = response._id

        performSerializedBackgroundWrite(writeBlock: { backgroundRealm in
            guard let edition = backgroundRealm.object(ofType: CocoaHubEdition.self, forPrimaryKey: editionId) else { return }

            response.articles.forEach { article in
                if let index = edition.articles.index(of: article) {
                    edition.articles[index] = article
                } else {
                    edition.articles.append(article)
                }
            }

            backgroundRealm.add(edition, update: .modified)
        }, disableAutorefresh: false, completionBlock: completion)
    }

    private let serialQueue = DispatchQueue(label: "Database Serial", qos: .userInteractive)

    /// Performs a write transaction in the background
    ///
    /// - Parameters:
    ///   - writeBlock: The block that will modify the database in the background (autoreleasepool is created automatically)
    ///   - disableAutorefresh: Whether to disable autorefresh on the main Realm instance while the write is in progress
    ///   - createTransaction: Whether the method should create its own write transaction or use the one already in place
    ///   - notificationTokensToSkip: An array of `NotificationToken` that should not be notified when the write is committed
    ///   - completionBlock: A block to be called when the operation is completed (called on the main queue)
    internal func performSerializedBackgroundWrite(writeBlock: @escaping (Realm) throws -> Void,
                                                   disableAutorefresh: Bool = false,
                                                   createTransaction: Bool = true,
                                                   notificationTokensToSkip: [NotificationToken] = [],
                                                   completionBlock: ((Error?) -> Void)? = nil) {
        if disableAutorefresh { realm.autorefresh = false }

        serialQueue.async {
            var storageError: Error?

            self.storageQueue.addOperation { [unowned self] in
                autoreleasepool {
                    do {
                        let backgroundRealm = try self.makeRealm(on: self.dispatchQueue)

                        if createTransaction { backgroundRealm.beginWrite() }

                        try writeBlock(backgroundRealm)

                        if createTransaction {
                            try backgroundRealm.commitWrite(withoutNotifying: notificationTokensToSkip)
                        } else {
                            assert(notificationTokensToSkip.count == 0, "It doesn't make sense to use createTransaction=false when you need to skip notification tokens")
                        }

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

        performSerializedBackgroundWrite(writeBlock: { [weak self] backgroundRealm in
            guard let self = self else { return }

            let resolvedObjects = safeObjects.compactMap { backgroundRealm.resolve($0) }

            guard resolvedObjects.count == safeObjects.count else {
                os_log("A background database modification failed because some objects couldn't be resolved'", log: self.log, type: .fault)
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
            bgFavorite.isDeleted = true
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

    public lazy var featuredSectionsObservable: Observable<Results<FeaturedSection>> = {
        let predicate = NSPredicate(format: "isPublished = true AND content.@count > 0")
        let sections = self.realm.objects(FeaturedSection.self).filter(predicate)

        return Observable.collection(from: sections)
    }()

    public lazy var scheduleObservable: Observable<Results<ScheduleSection>> = {
        let currentEvents = self.realm.objects(Event.self).filter("isCurrent == true")

        return Observable.collection(from: currentEvents).map({ $0.first?.identifier }).flatMap { (identifier: String?) -> Observable<Results<ScheduleSection>> in
            let sections = self.realm.objects(ScheduleSection.self).filter("eventIdentifier == %@", identifier ?? "").sorted(byKeyPath: "representedDate")

            return Observable.collection(from: sections)
        }
    }()

    public lazy var eventHeroObservable: Observable<EventHero?> = {
        let hero = self.realm.objects(EventHero.self)

        return Observable.collection(from: hero).map { $0.first }
    }()

    public lazy var communityNewsItemsObservable: Observable<Results<CommunityNewsItem>> = {
        let predicate = NSPredicate(format: "summary != nil AND isFeatured = false")
        let items = realm.objects(CommunityNewsItem.self).filter(predicate).sorted(byKeyPath: "date", ascending: false)

        return Observable.collection(from: items)
    }()

    public lazy var featuredCommunityNewsItemsObservable: Observable<Results<CommunityNewsItem>> = {
        let predicate = NSPredicate(format: "summary != nil AND isFeatured = true")
        let items = realm.objects(CommunityNewsItem.self).filter(predicate).sorted(byKeyPath: "date", ascending: false)

        return Observable.collection(from: items)
    }()

    public lazy var cocoaHubEditionsObservable: Observable<Results<CocoaHubEdition>> = {
        let items = realm.objects(CocoaHubEdition.self).sorted(byKeyPath: "index", ascending: false)

        return Observable.collection(from: items)
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
            os_log("DELETE ERROR: Bookmark not found with identifier %{public}@", log: log, type: .error, identifier)
            return
        }

        modify(bookmark) { bgBookmark in
            bgBookmark.realm?.delete(bgBookmark)
        }
    }

    public func softDeleteBookmark(with identifier: String) {
        guard let bookmark = bookmark(with: identifier) else {
            os_log("SOFT DELETE ERROR: Bookmark not found with identifier %{public}@", log: log, type: .error, identifier)
            return
        }

        modify(bookmark) { bgBookmark in
            bgBookmark.isDeleted = true
            bgBookmark.deletedAt = Date()
        }
    }

    public func moveBookmark(with identifier: String, to timecode: Double) {
        guard let bookmark = bookmark(with: identifier) else {
            os_log("MOVE ERROR: Bookmark not found with identifier %{public}@", log: log, type: .error, identifier)
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
