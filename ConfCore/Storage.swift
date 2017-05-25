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

public final class Storage {
    
    private let realmConfig: Realm.Configuration
    public let realm: Realm
        
    public init(_ configuration: Realm.Configuration) throws {
        var config = configuration
        config.migrationBlock = Storage.migrate(migration:oldVersion:)
        
        self.realmConfig = config
        self.realm = try Realm(configuration: config)
    }
    
    internal static func migrate(migration: Migration, oldVersion: UInt64) {
        if oldVersion < 10 {
            // alpha cleanup
            migration.deleteData(forType: "Event")
            migration.deleteData(forType: "Track")
            migration.deleteData(forType: "Room")
            migration.deleteData(forType: "Favorite")
            migration.deleteData(forType: "SessionProgress")
            migration.deleteData(forType: "Session")
            migration.deleteData(forType: "SessionInstance")
            migration.deleteData(forType: "SessionAsset")
            migration.deleteData(forType: "SessionAsset")
        }
        if oldVersion < 15 {
            // download model removal
            migration.deleteData(forType: "Download")
        }
    }
    
    /// Performs a write transaction on the database using `block`, on the main queue
    public func update(with block: @escaping () -> Void) {
        do {
            try realm.write {
                block()
            }
        } catch {
            NSLog("Error performing realm write: \(error)")
        }
    }
    
    /// Performs a write transaction on the database using `block`, on the current queue
    public func unmanagedUpdate(with block: @escaping (_ realm: Realm) -> Void) {
        do {
            let tempRealm = try Realm(configuration: self.realmConfig)
            
            try tempRealm.write {
                block(tempRealm)
            }
        } catch {
            NSLog("Error initializing temporary realm or performing background write: \(error)")
        }
    }
    
    public func unmanagedObject<T: Object>(of type: T.Type, with primaryKey: String) -> T? {
        do {
            let tempRealm = try Realm(configuration: self.realmConfig)
            
            return tempRealm.object(ofType: type, forPrimaryKey: primaryKey)
        } catch {
            return nil
        }
    }
    
    public func unmanagedObjects<T: Object>(of type: T.Type, with predicate: NSPredicate) -> Results<T>? {
        do {
            let tempRealm = try Realm(configuration: self.realmConfig)
            
            return tempRealm.objects(type).filter(predicate)
        } catch {
            return nil
        }
    }
    
    func store(sessionsResult: Result<SessionsResponse, APIError>, scheduleResult: Result<ScheduleResponse, APIError>, completion: @escaping () -> Void) {
        if case let .error(sessionsError) = sessionsResult {
            print("Error downloading sessions: \(sessionsError)")
        }
        if case let .error(scheduleError) = scheduleResult {
            print("Error downloading schedule: \(scheduleError)")
        }
        
        guard case let .success(sessionsResponse) = sessionsResult, case let .success(scheduleResponse) = scheduleResult else {
            return
        }
        
        self.realm.beginWrite()
        
        // Merge existing session data, preserving user-defined data
        let consolidatedSessions = sessionsResponse.sessions.map { newSession -> (Session) in
            return autoreleasepool {
                if let existingSession = self.realm.object(ofType: Session.self, forPrimaryKey: newSession.identifier) {
                    existingSession.merge(with: newSession, in: self.realm)
                    
                    return existingSession
                } else {
                    return newSession
                }
            }
        }
        
        // Associate sessions with events
        sessionsResponse.events.forEach { event in
            autoreleasepool {
                let sessions = consolidatedSessions.filter({ $0.eventIdentifier == event.identifier })
                
                event.sessions.append(objectsIn: sessions)
            }
        }
        
        // Associate assets with sessions
        consolidatedSessions.forEach { session in
            autoreleasepool {
                let components = session.identifier.components(separatedBy: "-")
                guard components.count == 2 else { return }
                guard let year = Int(components[0]) else { return }
                
                session.assets.removeAll()
                
                // Merge assets, preserving user-defined data
                let assets = sessionsResponse.assets.filter({ $0.year == year && $0.sessionId == components[1] }).map { newAsset -> (SessionAsset) in
                    if let existingAsset = self.realm.object(ofType: SessionAsset.self, forPrimaryKey: newAsset.identifier) {
                        existingAsset.merge(with: newAsset, in: self.realm)
                        
                        return existingAsset
                    } else {
                        return newAsset
                    }
                }
                
                session.assets.append(objectsIn: assets)
            }
        }
        
        // Merge existing instance data, preserving user-defined data
        scheduleResponse.instances.forEach { newInstance in
            return autoreleasepool {
                if let existingInstance = self.realm.object(ofType: SessionInstance.self, forPrimaryKey: newInstance.identifier) {
                    existingInstance.merge(with: newInstance, in: self.realm)
                    
                    self.realm.add(existingInstance, update: true)
                } else {
                    self.realm.add(newInstance, update: true)
                }
            }
        }
        
        // Save everything
        self.realm.add(scheduleResponse.rooms, update: true)
        self.realm.add(scheduleResponse.tracks, update: true)
        self.realm.add(sessionsResponse.events, update: true)
        
        do {
            try self.realm.commitWrite()
            
            self.updateAssociationsAndCreateViews(in: self.realm, completion: completion)
        } catch {
            NSLog("Realm error: \(error)")
        }
    }
    
    private func updateAssociationsAndCreateViews(in targetRealm: Realm, completion: @escaping () -> Void) {
        targetRealm.beginWrite()
        
        // add instances to rooms
        targetRealm.objects(Room.self).forEach { room in
            let instances = targetRealm.objects(SessionInstance.self).filter("roomName == %@", room.name)
            
            room.instances.append(objectsIn: instances)
        }
        
        // add instances and sessions to events
        targetRealm.objects(Event.self).forEach { event in
            let instances = targetRealm.objects(SessionInstance.self).filter("eventIdentifier == %@", event.identifier)
            let sessions = targetRealm.objects(Session.self).filter("eventIdentifier == %@", event.identifier)
            
            event.sessionInstances.append(objectsIn: instances)
            event.sessions.append(objectsIn: sessions)
        }
        
        // add instances and sessions to tracks
        targetRealm.objects(Track.self).forEach { track in
            let instances = targetRealm.objects(SessionInstance.self).filter("trackName == %@", track.name)
            let sessions = targetRealm.objects(Session.self).filter("trackName == %@", track.name)
            
            track.instances.append(objectsIn: instances)
            track.sessions.append(objectsIn: sessions)
        }
        
        // add live video assets to sessions
        targetRealm.objects(SessionAsset.self).filter("rawAssetType == %@", SessionAssetType.liveStreamVideo.rawValue).forEach { liveAsset in
            if let session = targetRealm.objects(Session.self).filter("year == %d AND number == %@", liveAsset.year, liveAsset.sessionId).first {
                session.assets.append(liveAsset)
            }
        }
        
        // Create schedule view
        
        targetRealm.objects(ScheduleSection.self).forEach({ targetRealm.delete($0) })
        
        let instances = targetRealm.objects(SessionInstance.self).sorted(by: SessionInstance.standardSort)
        
        var previousStartTime: Date? = nil
        for instance in instances {
            guard instance.startTime != previousStartTime else { continue }
            
            autoreleasepool {
                let instancesForSection = instances.filter({ $0.startTime == instance.startTime })
                
                let section = ScheduleSection()
                
                section.representedDate = instance.startTime
                section.eventIdentifier = instance.eventIdentifier
                section.instances.append(objectsIn: instancesForSection)
                section.identifier = ScheduleSection.identifierFormatter.string(from: instance.startTime)
                
                targetRealm.add(section, update: true)
                
                previousStartTime = instance.startTime
            }
        }
        
        do {
            try targetRealm.commitWrite()
            
            DispatchQueue.main.async {
                completion()
            }
        } catch {
            NSLog("Realm error while consolidating schedule: \(error)")
        }
    }
    
    internal func store(liveVideosResult: Result<[SessionAsset], APIError>) {
        guard case .success(let assets) = liveVideosResult else { return }
        
        self.realm.beginWrite()
        
        assets.forEach { asset in
            self.realm.add(asset, update: true)
            
            if let session = self.realm.objects(Session.self).filter("year == %d AND number == %@", asset.year, asset.sessionId).first {
                session.assets.append(asset)
            }
        }
        
        do {
            try self.realm.commitWrite()
        } catch {
            NSLog("Error syncing live videos: \(error)")
        }
    }
    
    public lazy var events: Observable<Results<Event>> = {
        let eventsSortedByDateDescending = self.realm.objects(Event.self).sorted(byKeyPath: "startDate", ascending: false)
        
        return Observable.collection(from: eventsSortedByDateDescending)
    }()
    
    public lazy var sessionsObservable: Observable<Results<Session>> = {
        return Observable.collection(from: self.realm.objects(Session.self))
    }()
    
    public var sessions: Results<Session> {
        return self.realm.objects(Session.self).filter("assets.@count > 0")
    }
    
    public func session(with identifier: String) -> Session? {
        return realm.object(ofType: Session.self, forPrimaryKey: identifier)
    }
    
    public func createFavorite(for session: Session) {
        do {
            try realm.write {
                session.favorites.append(Favorite())
            }
        } catch {
            NSLog("Error creating favorite for session \(session)")
        }
    }
    
    public var isEmpty: Bool {
        return realm.objects(Event.self).count <= 0
    }
    
    public func removeFavorite(for session: Session) {
        guard let favorite = session.favorites.first else { return }
        
        do {
            try realm.write {
                realm.delete(favorite)
            }
        } catch {
            NSLog("Error creating favorite for session \(session)")
        }
    }
    
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
    
    public func bookmark(with identifier: String) -> Bookmark? {
        return realm.object(ofType: Bookmark.self, forPrimaryKey: identifier)
    }
    
    public func deleteBookmark(with identifier: String) {
        _ = realm.refresh()
        
        update {
            guard let bookmark = self.bookmark(with: identifier) else {
                NSLog("DELETE ERROR: Unable to find bookmark with identifier \(identifier)")
                return
            }
        
            self.realm.delete(bookmark)
        }
    }
    
    public func softDeleteBookmark(with identifier: String) {
        _ = realm.refresh()
        
        update {
            guard let bookmark = self.bookmark(with: identifier) else {
                NSLog("SOFT DELETE ERROR: Unable to find bookmark with identifier \(identifier)")
                return
            }
            
            bookmark.isDeleted = true
            bookmark.deletedAt = Date()
        }
    }
    
    public func moveBookmark(with identifier: String, to timecode: Double) {
        _ = realm.refresh()
        
        update {
            guard let bookmark = self.bookmark(with: identifier) else {
                NSLog("MOVE ERROR: Unable to find bookmark with identifier \(identifier)")
                return
            }
            
            bookmark.timecode = timecode
            self.realm.add(bookmark, update: true)
        }
    }
    
    public func updateDownloadedFlag(_ isDownloaded: Bool, forAssetWithRelativeLocalURL filePath: String) {
        DispatchQueue.main.async {
            guard let asset = self.realm.objects(SessionAsset.self).filter("relativeLocalURL == %@", filePath).first else { return }
            
            self.update {
                asset.session.first?.isDownloaded = isDownloaded
            }
        }
    }
    
    public var allEvents: [Event] {
        return realm.objects(Event.self).sorted(byKeyPath: "startDate", ascending: false).toArray()
    }
    
}
