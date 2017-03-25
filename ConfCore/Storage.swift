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
    
    private let realm: Realm
    
    public init(_ configuration: Realm.Configuration) throws {
        self.realm = try Realm(configuration: configuration)
    }
    
    public func store(objects: [Object], withoutNotifying tokens: [NotificationToken] = []) {
        realm.beginWrite()
        
        realm.add(objects, update: true)
        
        do {
            try realm.commitWrite(withoutNotifying: tokens)
        } catch {
            NSLog("Realm error: \(error)")
        }
    }
    
    private func associateSessionInstances(with event: Event, withoutNotifying tokens: [NotificationToken]) {
        let instances = realm.objects(SessionInstance.self).filter("startTime >= %@ AND endTime <= %@", event.startDate, event.endDate)
        event.sessionInstances = List<SessionInstance>(instances)
        
        store(objects: [event], withoutNotifying: tokens)
    }
    
    public func store(schedule: ScheduleResponse, withoutNotifying tokens: [NotificationToken] = []) {
        schedule.rooms.forEach { room in
            let instances = schedule.instances.filter({ $0.roomName == room.name })
            
            room.instances.append(objectsIn: instances)
        }
        
        schedule.tracks.forEach { track in
            let instances = schedule.instances.filter({ $0.trackName == track.name })
            
            track.instances.append(objectsIn: instances)
        }
        
        store(objects: schedule.instances, withoutNotifying: tokens)
        store(objects: schedule.rooms, withoutNotifying: tokens)
        store(objects: schedule.tracks, withoutNotifying: tokens)
        
        realm.objects(Event.self).forEach({ self.associateSessionInstances(with: $0, withoutNotifying: tokens) })
    }
    
    public func store(sessionsResponse: SessionsResponse, withoutNotifying tokens: [NotificationToken] = []) {
        let tracks = realm.objects(Track.self).toArray()
        
        sessionsResponse.events.forEach { event in
            let sessions = sessionsResponse.sessions.filter({ $0.eventIdentifier == event.identifier })
            
            event.sessions.append(objectsIn: sessions)
        }
        
        sessionsResponse.sessions.forEach { session in
            tracks.filter({ $0.name == session.trackName }).first?.sessions.append(session)
            
            let components = session.identifier.components(separatedBy: "-")
            guard components.count == 2 else { return }
            guard let year = Int(components[0]) else { return }
            
            let assets = sessionsResponse.assets.filter({ $0.year == year && $0.sessionId == components[1] })
            
            session.assets.append(objectsIn: assets)
        }
        
        sessionsResponse.events.forEach({ self.associateSessionInstances(with: $0, withoutNotifying: tokens) })
        
        store(objects: sessionsResponse.assets, withoutNotifying: tokens)
        store(objects: sessionsResponse.sessions, withoutNotifying: tokens)
        store(objects: sessionsResponse.events, withoutNotifying: tokens)
        store(objects: tracks, withoutNotifying: tokens)
    }
    
    public lazy var events: Observable<Results<Event>> = {
        let eventsSortedByDateDescending = self.realm.objects(Event.self).sorted(byKeyPath: "startDate", ascending: false)
        
        return Observable.collection(from: eventsSortedByDateDescending)
    }()
    
}
