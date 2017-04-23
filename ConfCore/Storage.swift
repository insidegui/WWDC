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
    private let realm: Realm
    private var backgroundRealm: Realm!
    
    private let backgroundQueue = DispatchQueue(label: "Storage", qos: .userInitiated)
    
    public init(_ configuration: Realm.Configuration) throws {
        self.realmConfig = configuration
        self.realm = try Realm(configuration: configuration)
    }
    
    func store(sessionsResult: Result<SessionsResponse, APIError>, scheduleResult: Result<ScheduleResponse, APIError>) {
        backgroundQueue.async {
            if self.backgroundRealm == nil {
                do {
                    self.backgroundRealm = try Realm(configuration: self.realmConfig)
                } catch {
                    fatalError("Error initializing background Realm: \(error)")
                }
            }
            
            if case let .error(sessionsError) = sessionsResult {
                print("Error downloading sessions: \(sessionsError)")
            }
            if case let .error(scheduleError) = scheduleResult {
                print("Error downloading schedule: \(scheduleError)")
            }
            
            guard case let .success(sessionsResponse) = sessionsResult, case let .success(scheduleResponse) = scheduleResult else {
                return
            }
            
            self.backgroundRealm.beginWrite()
            
            // Add sessions and session instances to tracks
            scheduleResponse.tracks.forEach { track in
                track.sessions.append(objectsIn: sessionsResponse.sessions.filter({ $0.trackName == track.name }))
                track.instances.append(objectsIn: scheduleResponse.instances.filter({ $0.trackName == track.name }))
            }
            
            // Associate sessions with events
            sessionsResponse.events.forEach { event in
                let sessions = sessionsResponse.sessions.filter({ $0.eventIdentifier == event.identifier })
                
                event.sessions.append(objectsIn: sessions)
            }
            
            // Associate assets with sessions
            sessionsResponse.sessions.forEach { session in
                let components = session.identifier.components(separatedBy: "-")
                guard components.count == 2 else { return }
                guard let year = Int(components[0]) else { return }
                
                let assets = sessionsResponse.assets.filter({ $0.year == year && $0.sessionId == components[1] })
                
                session.assets.append(objectsIn: assets)
            }
            
            // Associate rooms with session instances
            scheduleResponse.rooms.forEach { room in
                let instances = scheduleResponse.instances.filter({ $0.roomName == room.name })
                
                room.instances.append(objectsIn: instances)
            }
            
            // Save everything
            self.backgroundRealm.add(scheduleResponse.instances, update: true)
            self.backgroundRealm.add(scheduleResponse.rooms, update: true)
            self.backgroundRealm.add(scheduleResponse.tracks, update: true)
            self.backgroundRealm.add(sessionsResponse.events, update: true)
            
            // Associate instances with events
            scheduleResponse.instances.forEach { instance in
                guard let session = instance.session else { return }
                
                guard let event = self.backgroundRealm.objects(Session.self).filter({ $0.identifier == session.identifier && $0.number == session.number }).first?.event.first else {
                    return
                }
                
                event.sessionInstances.append(instance)
            }
            
            do {
                try self.backgroundRealm.commitWrite()
            } catch {
                NSLog("Realm error: \(error)")
            }
        }
    }
    
    public lazy var events: Observable<Results<Event>> = {
        let eventsSortedByDateDescending = self.realm.objects(Event.self).sorted(byKeyPath: "startDate", ascending: false)
        
        return Observable.collection(from: eventsSortedByDateDescending)
    }()
    
    public lazy var sessions: Observable<Results<Session>> = {
        return Observable.collection(from: self.realm.objects(Session.self))
    }()
    
    public func session(with identifier: String) -> Session? {
        return realm.object(ofType: Session.self, forPrimaryKey: identifier)
    }
    
}
