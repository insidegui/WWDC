//
//  LiveSession.swift
//  WWDC
//
//  Created by Guilherme Rambo on 06/06/16.
//  Copyright © 2016 Guilherme Rambo. All rights reserved.
//

import Foundation

class LiveSession {
    
    var id = 0
    var title = ""
    var summary = ""
    var startsAt: NSDate?
    var endsAt: NSDate?
    var streamURL: NSURL?
    var alternateStreamURL = ""
    var isLiveRightNow = false
    
}