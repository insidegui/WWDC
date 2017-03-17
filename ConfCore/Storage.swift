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
    
    public typealias ScheduleObservable = Observable<Results<SessionInstance>>
    
    public lazy var schedule: ScheduleObservable = {
        let latestEvent = self.realm.objects(Event.self).sorted(byKeyPath: "startDate", ascending: false).first
        
        return Observable.from(latestEvent).flatMap { event -> ScheduleObservable in
            let results = self.realm.objects(SessionInstance.self)
                                    .filter("startTime >= %@ AND endTime <= %@", event.startDate, event.endDate)
                                    .sorted(byKeyPath: "startTime")
            
            return Observable.collection(from: results)
        }
    }()
    
}
