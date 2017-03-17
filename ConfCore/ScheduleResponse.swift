//
//  ScheduleResponse.swift
//  WWDC
//
//  Created by Guilherme Rambo on 21/02/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Foundation

public struct ScheduleResponse {
    
    public let rooms: [Room]
    public let tracks: [Track]
    public let instances: [SessionInstance]
    
}
