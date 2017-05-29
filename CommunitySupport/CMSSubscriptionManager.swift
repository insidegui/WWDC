//
//  CMSSubscriptionManager.swift
//  WWDC
//
//  Created by Guilherme Rambo on 15/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Foundation
import CloudKit

internal final class CMSSubscriptionManager {
    
    private let defaults = UserDefaults.standard
    
    var profileSubscriptionCreated: Bool {
        get {
            return defaults.bool(forKey: #function)
        }
        set {
            defaults.set(newValue, forKey: #function)
        }
    }
    
}
