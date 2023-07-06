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
        var initialValue: some Publisher<Self, Error> { Just(self).setFailureType(to: Error.self) }
        var valuePublisher: some Publisher<Self, Error> { RealmSwift.valuePublisher(self, keyPaths: keyPaths) }

        switch (share, includeInitialValue) {
        case (true, true):
            return Publishers.Concatenate(prefix: initialValue, suffix: valuePublisher.share()).eraseToAnyPublisher()
        case (false, true):
            return Publishers.Concatenate(prefix: initialValue, suffix: valuePublisher).eraseToAnyPublisher()
        case (true, false):
            return valuePublisher.share().eraseToAnyPublisher()
        case (false, false):
            return valuePublisher.eraseToAnyPublisher()
        }
    }
}
