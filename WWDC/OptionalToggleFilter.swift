//
//  OptionalToggleFilter.swift
//  WWDC
//
//  Created by Dave DeLong on 6/11/24.
//  Copyright © 2024 Guilherme Rambo. All rights reserved.
//

import Foundation

struct OptionalToggleFilter: FilterType {
    
    var identifier: FilterIdentifier
    var isOn: Bool?

    var onPredicate: NSPredicate
    var offPredicate: NSPredicate
    
    init(id identifier: FilterIdentifier, onPredicate: NSPredicate, offPredicate: NSPredicate) {
        self.identifier = identifier
        self.onPredicate = onPredicate
        self.offPredicate = offPredicate
    }

    var isEmpty: Bool {
        return isOn == nil
    }

    var predicate: NSPredicate? {
        switch isOn {
        case true: 
            return onPredicate
        case false:
            return offPredicate
        default:
            return nil
        }
    }

    mutating func reset() {
        isOn = nil
    }

    var state: State {
        State(isOn: isOn)
    }

    struct State: Codable {
        let isOn: Bool?
    }
}
