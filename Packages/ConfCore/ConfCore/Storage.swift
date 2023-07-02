//
//  Storage.swift
//  WWDC
//
//  Created by Guilherme Rambo on 17/03/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Combine
import Foundation
import RealmSwift
import OSLog
import OrderedCollections

public final class Storage: Logging, Signposting {

    public let realmConfig: Realm.Configuration
    public let realm: Realm

    private var disposeBag: Set<AnyCancellable> = []
    public static let log = makeLogger()
    public static var signposter = makeSignposter()

    public init(_ realm: Realm) {
        self.realmConfig = realm.configuration
        self.realm = realm

        // This used to be necessary because of CPU usage in the app during script indexing, but it causes a long period of time during indexing where content doesn't reflect what's on the database,
        // including for user actions such as favoriting, etc. Tested with the current version of Realm in the app and it doesn't seem to be an issue anymore.
//        DistributedNotificationCenter.default().publisher(for: .TranscriptIndexingDidStart).sink(receiveValue: { [unowned self] _ in
//            os_log("Locking Realm auto-updates until transcript indexing is finished", log: self.log, type: .info)
//
//            self.realm.autorefresh = false
//        }).store(in: &disposeBag)
//
//        DistributedNotificationCenter.default().publisher(for: .TranscriptIndexingDidStop).sink(receiveValue: { [unowned self] _ in
//            os_log("Realm auto-updates unlocked", log: self.log, type: .info)
//
//            self.realm.autorefresh = true
//        }).store(in: &disposeBag)

        deleteOldEventsIfNeeded()
    }

    // In order to call this with a specific queue, you must already be on the target queue
    public func makeRealm(on queue: DispatchQueue? = nil) throws -> Realm {
        return try Realm(configuration: realmConfig, queue: queue)
    }

    /// This is the background dispatch queue for Realm updates to take place not on the main thread.
    /// While it is not on the main thread, it is very important for the changes to happen quickly so the qos is set to userInitiated
    private lazy var dispatchQueue = DispatchQueue(label: "WWDC Storage", qos: .userInitiated)

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
            log.error("Error deleting old events: \(String(describing: error), privacy: .public)")
        }
    }

    public static func migrate(migration: Migration, oldVersion: UInt64) {
        let migrator = StorageMigrator(migration: migration, oldVersion: oldVersion)

        migrator.perform()
    }

    func store(contentResult: Result<ContentsResponse, APIError>, completion: @escaping (Error?) -> Void) {
        let state = signposter.beginInterval("store content result", id: signposter.makeSignpostID(), "begin")
        let contentsResponse: ContentsResponse
        do {
            contentsResponse = try contentResult.get()
        } catch {
            log.error("Error downloading contents:\n\(String(describing: error), privacy: .public)")
            signposter.endInterval("store content result", state, "end")
            completion(error)
            return
        }

        performSerializedBackgroundWrite(
            disableAutorefresh: true
        ) { [weak self] in
            self?.signposter.endInterval("store content result", state, "end")
            completion($0)
        } writeBlock: { backgroundRealm in
            // Save everything
            backgroundRealm.add(contentsResponse.rooms, update: .all)
            backgroundRealm.add(contentsResponse.tracks, update: .all)
            backgroundRealm.add(contentsResponse.events, update: .all)

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
            let mergeInstances = Self.signposter.beginInterval("store content result", id: Self.signposter.makeSignpostID(), "merge instances")
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
            Self.signposter.endInterval("store content result", mergeInstances)

            // add instances to rooms
            let instancesToRooms = Self.signposter.beginInterval("store content result", id: Self.signposter.makeSignpostID(), "add instances to rooms")
            backgroundRealm.objects(Room.self).forEach { room in
                let instances = backgroundRealm.objects(SessionInstance.self).filter("roomIdentifier == %@", room.identifier)

                room.instances.removeAll()
                instances.forEach {
                    $0.roomName = room.name
                    // append(contentsOf: other) just does a for loop so we avoid double iteration by doing this
                    room.instances.append($0)
                }
            }
            Self.signposter.endInterval("store content result", instancesToRooms)

            // add instances and sessions to events
            let instancesToEvents = Self.signposter.beginInterval("store content result", id: Self.signposter.makeSignpostID(), "add instances and sessions to events")
            backgroundRealm.objects(Event.self).forEach { event in
                let instances = backgroundRealm.objects(SessionInstance.self).filter("eventIdentifier == %@", event.identifier)
                let sessions = backgroundRealm.objects(Session.self).filter("eventIdentifier == %@", event.identifier)

                event.sessionInstances.removeAll()
                event.sessionInstances.forEach {
                    $0.session?.eventStartDate = event.startDate
                    event.sessionInstances.append($0)
                }

                event.sessions.removeAll()
                sessions.forEach {
                    $0.eventStartDate = event.startDate
                    // append(contentsOf: other) just does a for loop so we avoid double iteration by doing this
                    event.sessions.append($0)
                }
            }
            Self.signposter.endInterval("store content result", instancesToEvents)

            // add instances and sessions to tracks
            let instancesToTracks = Self.signposter.beginInterval("store content result", id: Self.signposter.makeSignpostID(), "add instances and sessions to tracks")
            backgroundRealm.objects(Track.self).forEach { track in
                let instances = backgroundRealm.objects(SessionInstance.self).filter("trackIdentifier == %@", track.identifier)
                let sessions = backgroundRealm.objects(Session.self).filter("trackIdentifier == %@", track.identifier)

                track.instances.removeAll()
                instances.forEach { instance in
                    instance.trackName = track.name
                    instance.session?.trackName = track.name
                    instance.session?.trackOrder = track.order
                    // append(contentsOf: other) just does a for loop so we avoid double iteration by doing this
                    track.instances.append(instance)
                }

                track.sessions.removeAll()
                sessions.forEach {
                    $0.trackName = track.name
                    $0.trackOrder = track.order
                    // append(contentsOf: other) just does a for loop so we avoid double iteration by doing this
                    track.sessions.append($0)
                }
            }
            Self.signposter.endInterval("store content result", instancesToTracks)

            // add live video assets to sessions
            let liveVideoAssets = Self.signposter.beginInterval("store content result", id: Self.signposter.makeSignpostID(), "add live video assets to sessions")
            backgroundRealm.objects(SessionAsset.self).filter("rawAssetType == %@", SessionAssetType.liveStreamVideo.rawValue).forEach { liveAsset in
                if let session = backgroundRealm.objects(Session.self).filter("ANY event.year == %d AND number == %@", liveAsset.year, liveAsset.sessionId).first {
                    if !session.assets.contains(liveAsset) {
                        session.assets.append(liveAsset)
                    }
                }
            }
            Self.signposter.endInterval("store content result", liveVideoAssets)

            // Associate session resources with Session objects in database
            let sessionResources = Self.signposter.beginInterval("store content result", id: Self.signposter.makeSignpostID(), "associate session resources")
            backgroundRealm.objects(RelatedResource.self).filter("type == %@", RelatedResourceType.session.rawValue).forEach { resource in
                if let session = backgroundRealm.object(ofType: Session.self, forPrimaryKey: resource.identifier) {
                    resource.session = session
                }
            }
            Self.signposter.endInterval("store content result", sessionResources)

            // Remove tracks that don't include any future session instances nor any sessions with video/live video
            let emptyTracksState = Self.signposter.beginInterval("store content result", id: Self.signposter.makeSignpostID(), "delete empty tracks")
            let emptyTracks = backgroundRealm.objects(Track.self)
                .filter("SUBQUERY(sessions, $session, ANY $session.assets.rawAssetType = %@ OR ANY $session.assets.rawAssetType = %@).@count == 0", SessionAssetType.streamingVideo.rawValue, SessionAssetType.liveStreamVideo.rawValue)
            backgroundRealm.delete(emptyTracks)
            Self.signposter.endInterval("store content result", emptyTracksState)

            // Create schedule view
            let createScheduleView = Self.signposter.beginInterval("store content result", id: Self.signposter.makeSignpostID(), "schedule view")
            let sectionsInRealm = backgroundRealm.objects(ScheduleSection.self)
            let instances = backgroundRealm.objects(SessionInstance.self)

            // Group all instances by common start time
            // Technically, a secondary grouping on event should be used, in practice we haven't seen
            // separate events that overlap in time. Someday this might hurt
            // For content updates that don't really change much, like most of the year.
            // Doing the diffing on the sections is an order of magnitude faster (28ms -> 4ms)
            let newSections = Dictionary(grouping: instances, by: \.startTime)
            var merged = Set<Date>()
            sectionsInRealm.forEach { existing in
                if let new = newSections[existing.representedDate] {
                    // Section is in new and old, update it's instances
                    existing.instances.removeAll()
                    existing.instances.append(objectsIn: new)
                    merged.insert(existing.representedDate)
                } else {
                    // Section is not in the new data, delete it
                    backgroundRealm.delete(existing)
                }
            }

            // Explicitly add new sections
            newSections.filter { !merged.contains($0.key) }.forEach { startTime, instances in
                let section = ScheduleSection()
                section.representedDate = startTime
                section.eventIdentifier = instances[0].eventIdentifier // 0 index ok, Dictionary grouping will never give us an empty array
                section.instances.removeAll()
                section.instances.append(objectsIn: instances)
                section.identifier = ScheduleSection.identifierFormatter.string(from: startTime)

                backgroundRealm.add(section, update: .all)
            }
            Self.signposter.endInterval("store content result", createScheduleView)
        }
    }

    internal func store(liveVideosResult: Result<[SessionAsset], APIError>) {
        let assets: [SessionAsset]
        do {
            assets = try liveVideosResult.get()
        } catch {
            log.error("Error downloading live videos:\n\(String(describing: error), privacy: .public)")
            return
        }

        performSerializedBackgroundWrite(writeBlock: { [weak self] backgroundRealm in
            guard let self = self else { return }

            assets.forEach { asset in
                asset.identifier = asset.generateIdentifier()

                self.log.info("Registering live asset with year \(asset.year, privacy: .public) and session number \(asset.sessionId, privacy: .public)")

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
            log.error("Error downloading featured sections:\n\(String(describing: error), privacy: .public)")
            completion(error)
            return
        }

        performSerializedBackgroundWrite(disableAutorefresh: true, completionBlock: completion) { backgroundRealm in
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
        }
    }

    internal func store(configResult: Result<ConfigResponse, APIError>, completion: @escaping (Error?) -> Void) {
        let response: ConfigResponse

        do {
            response = try configResult.get()
        } catch {
            log.error("Error downloading config:\n\(String(describing: error), privacy: .public)")
            completion(error)
            return
        }
        
        performSerializedBackgroundWrite(disableAutorefresh: false, completionBlock: completion) { backgroundRealm in
            // We currently only care about whatever the latest event hero is.
            let existingHeroData = backgroundRealm.objects(EventHero.self)
            backgroundRealm.delete(existingHeroData)
        }

        guard let hero = response.eventHero else {
            log.debug("Config response didn't contain an event hero")
            return
        }

        performSerializedBackgroundWrite(disableAutorefresh: false, completionBlock: completion) { backgroundRealm in
            backgroundRealm.add(hero, update: .all)
        }
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
    internal func performSerializedBackgroundWrite(disableAutorefresh: Bool = false,
                                                   createTransaction: Bool = true,
                                                   notificationTokensToSkip: [NotificationToken] = [],
                                                   completionBlock: ((Error?) -> Void)? = nil,
                                                   writeBlock: @escaping (Realm) throws -> Void) {
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

        performSerializedBackgroundWrite(createTransaction: false, writeBlock: { backgroundRealm in
            guard let resolvedObject = backgroundRealm.resolve(safeObject) else { return }

            try backgroundRealm.write {
                writeBlock(resolvedObject)
            }
        })
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

        performSerializedBackgroundWrite(createTransaction: false, writeBlock: { [weak self] backgroundRealm in
            guard let self = self else { return }

            let resolvedObjects = safeObjects.compactMap { backgroundRealm.resolve($0) }

            guard resolvedObjects.count == safeObjects.count else {
                log.fault("A background database modification failed because some objects couldn't be resolved'")
                return
            }

            try backgroundRealm.write {
                writeBlock(resolvedObjects)
            }
        })
    }

    public lazy var events: some Publisher<Results<Event>, Error> = {
        let eventsSortedByDateDescending = self.realm.objects(Event.self).sorted(byKeyPath: "startDate", ascending: false)

        return eventsSortedByDateDescending.collectionPublisher
    }()

    public lazy var sessionsObservable: some Publisher<Results<Session>, Error> = {
        return self.realm.objects(Session.self).collectionPublisher
    }()

    public var sessions: Results<Session> {
        return realm.objects(Session.self).filter("assets.@count > 0")
    }

    public func session(with identifier: String) -> Session? {
        return realm.object(ofType: Session.self, forPrimaryKey: identifier)
    }

    public var isEmpty: Bool {
        return realm.objects(Event.self).isEmpty
    }
    
    public func setFavorite(_ isFavorite: Bool, onSessionsWithIDs ids: [String]) {
        performSerializedBackgroundWrite(disableAutorefresh: false, createTransaction: true, writeBlock: { realm in
            let sessions = realm.objects(Session.self).filter(NSPredicate(format: "identifier IN %@", ids))

            sessions.forEach { session in
                if isFavorite {
                    guard !session.isFavorite else { return }
                    session.favorites.append(Favorite())
                } else {
                    session.favorites.forEach { $0.isDeleted = true }
                }
            }
        })
    }

    public lazy var eventsObservable: some Publisher<Results<Event>, Error> = {
        let events = realm.objects(Event.self).sorted(byKeyPath: "startDate", ascending: false)

        return events.collectionPublisher
    }()

    public lazy var focusesShallowObservable: some Publisher<Results<Focus>, Error> = {
        let focuses = realm.objects(Focus.self).sorted(byKeyPath: "name")

        return focuses.collectionChangedPublisher
    }()

    public lazy var tracks: Results<Track> = {
        let tracks = self.realm.objects(Track.self).sorted(byKeyPath: "order")

        return tracks
    }()

    public lazy var tracksShallowObservable: some Publisher<Results<Track>, Error> = {
        let tracks = self.realm.objects(Track.self).sorted(byKeyPath: "order")

        return tracks.collectionChangedPublisher
    }()

    public lazy var featuredSectionsObservable: some Publisher<Results<FeaturedSection>, Error> = {
        let predicate = NSPredicate(format: "isPublished = true AND content.@count > 0")
        let sections = self.realm.objects(FeaturedSection.self).filter(predicate)

        return sections.collectionPublisher
    }()

    public lazy var scheduleObservable: some Publisher<Results<ScheduleSection>, Error> = {
        let currentEvents = self.realm.objects(Event.self).filter("isCurrent == true")

        return currentEvents.collectionPublisher.map({ $0.first?.identifier }).flatMap { (identifier: String?) -> AnyPublisher<Results<ScheduleSection>, Error> in
            let sections = self.realm.objects(ScheduleSection.self).filter("eventIdentifier == %@", identifier ?? "").sorted(byKeyPath: "representedDate")

            return sections.collectionPublisher.eraseToAnyPublisher()
        }
    }()

    public lazy var scheduleShallowObservable: some Publisher<Results<ScheduleSection>, Error> = {
        let currentEvents = self.realm.objects(Event.self).filter("isCurrent == true")

        return currentEvents.collectionChangedPublisher.map({ $0.first?.identifier }).flatMap { (identifier: String?) -> AnyPublisher<Results<ScheduleSection>, Error> in
            let sections = self.realm.objects(ScheduleSection.self).filter("eventIdentifier == %@", identifier ?? "").sorted(byKeyPath: "representedDate")

            return sections.collectionChangedPublisher.eraseToAnyPublisher()
        }
    }()

    public lazy var eventHeroObservable: some Publisher<EventHero?, Error> = {
        let hero = self.realm.objects(EventHero.self)

        return hero.collectionPublisher.map { $0.first }
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
            log.error("DELETE ERROR: Bookmark not found with identifier \(identifier, privacy: .public)")
            return
        }

        modify(bookmark) { bgBookmark in
            bgBookmark.realm?.delete(bgBookmark)
        }
    }

    public func softDeleteBookmark(with identifier: String) {
        guard let bookmark = bookmark(with: identifier) else {
            log.error("SOFT DELETE ERROR: Bookmark not found with identifier \(identifier, privacy: .public)")
            return
        }

        modify(bookmark) { bgBookmark in
            bgBookmark.isDeleted = true
            bgBookmark.deletedAt = Date()
        }
    }

    public func moveBookmark(with identifier: String, to timecode: Double) {
        guard let bookmark = bookmark(with: identifier) else {
            log.error("MOVE ERROR: Bookmark not found with identifier \(identifier, privacy: .public)")
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

    public var eventsForFilteringShallowPublisher: some Publisher<Results<Event>, Error> {
        return realm.objects(Event.self)
            .filter("SUBQUERY(sessions, $session, ANY $session.assets.rawAssetType == %@).@count > %d", SessionAssetType.streamingVideo.rawValue, 0)
            .sorted(byKeyPath: "startDate", ascending: false)
            .collectionChangedPublisher
    }

    public var allSessionTypesShallowPublisher: some Publisher<[String], Error> {
        realm
            .objects(SessionInstance.self)
            .collectionChangedPublisher
            .map {
                Array(Set($0.map(\.rawSessionType)))
                    .sorted(by: { $0.localizedStandardCompare($1) == .orderedAscending })
            }
    }

    public var allTracks: [Track] {
        return realm.objects(Track.self).sorted(byKeyPath: "order").toArray()
    }

}

public extension RealmCollection where Self: RealmSubscribable {
    /// Similar to `changesetPublisher` but only emits a new value when the collection has additions or removals and ignores all upstream
    /// values caused by objects being modified
    var collectionChangedPublisher: some Publisher<Self, Error> {
        changesetPublisher
            .tryCompactMap { changeset in
                switch changeset {
                case .initial(let latestValue):
                    return latestValue
                case .update(let latestValue, let deletions, let insertions, _) where !deletions.isEmpty || !insertions.isEmpty:
                    return latestValue
                case .update:
                    return nil
                case .error(let error):
                    throw error
                }
            }
    }
}

private func merge<T>(old: List<T>, new: List<T>) {
    let diff = new.difference(from: old)
    for change in diff {
        switch change {
        case let .remove(offset: offset, element: _, associatedWith: _):
            old.remove(at: offset)
        case let .insert(offset: offset, element: element, associatedWith: _):
            old.insert(element, at: offset)
        }
    }
}
