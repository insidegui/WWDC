//
//  Realm+InMemory.swift
//  ConfCoreTests
//
//  Created by Anton Selyanin on 14/10/2017.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Foundation
import RealmSwift

extension Realm {
    static func makeInMemoryConfiguration() -> Realm.Configuration {
        return Realm.Configuration(inMemoryIdentifier: UUID().uuidString)
    }

    static func makeInMemory() -> Realm {
        return tryOrXCTFail(try Realm(configuration: makeInMemoryConfiguration()))
    }
}
