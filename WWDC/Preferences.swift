//
//  Preferences.swift
//  WWDC
//
//  Created by Guilherme Rambo on 13/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Foundation
import ThrowBack

final class Preferences {
    
    static let shared: Preferences = Preferences()
    
    private let defaults = UserDefaults.standard
    
    /// The URL for the folder where downloaded videos will be saved
    var localVideoStorageURL: URL {
        get {
            return URL(fileURLWithPath: TBPreferences.shared.localVideoStoragePath)
        }
        set {
            TBPreferences.shared.localVideoStoragePath = newValue.path
            
            defaults.set(newValue.path, forKey: #function)
        }
    }
    
}
