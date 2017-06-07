//
//  PathUtil.swift
//  WWDC
//
//  Created by Guilherme Rambo on 22/04/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa

final class PathUtil {
    
    static var appSupportPath: String {
        guard let identifier = Bundle.main.bundleIdentifier else {
            fatalError("Bundle identifier is nil, this should never happen")
        }
        
        let dir = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true).first!
        let path = dir + "/\(identifier)"
        
        return path
    }
    
}
