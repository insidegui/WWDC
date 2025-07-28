//
//  Realm+Combine.swift
//  WWDC
//
//  Created by Allen Humphreys on 6/9/23.
//  Copyright © 2023 Guilherme Rambo. All rights reserved.
//

import Combine
import RealmSwift

extension RealmSubscribable where Self: Object {
    func valuePublisher(share: Bool = true, includeInitialValue: Bool = true, keyPaths: [String]? = nil) -> some Publisher<Self, Error> {
        var valuePublisher: some Publisher<Self, Error> { RealmSwift.valuePublisher(self, keyPaths: keyPaths) }

        // by using `.multicast(subject: CurrentValueSubject(self))` we are sharing the upstream publisher
        // and also replaying the most recent value to new subscribers which is useful when
        // subscriptions come in at slightly different times
        switch (share, includeInitialValue) {
        case (true, true):
            return valuePublisher
                .prepend(self)
                .multicast(subject: CurrentValueSubject(self))
                .autoconnect()
                .eraseToAnyPublisher()
        case (false, true):
            return valuePublisher
                .prepend(self)
                .eraseToAnyPublisher()
        case (true, false):
            return valuePublisher
                .multicast(subject: CurrentValueSubject(self))
                .autoconnect()
                .eraseToAnyPublisher()
        case (false, false):
            return valuePublisher
                .eraseToAnyPublisher()
        }
    }
}
