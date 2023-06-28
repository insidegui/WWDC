//
//  ToggleFilter.swift
//  WWDC
//
//  Created by Guilherme Rambo on 27/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Foundation

struct ToggleFilter: FilterType {

    init(_ identifier: FilterIdentifier, predicate: NSPredicate?) {
        self.identifier = identifier
        self.customPredicate = predicate
    }

    var identifier: FilterIdentifier
    var isOn: Bool = false

    var customPredicate: NSPredicate?

    var isEmpty: Bool {
        return !isOn
    }

    var predicate: NSPredicate? {
        guard isOn else { return nil }

        return customPredicate
    }

    mutating func reset() {
        isOn = false
    }

    var state: State {
        State(isOn: isOn)
    }

    struct State: Codable {
        let isOn: Bool
    }
}
