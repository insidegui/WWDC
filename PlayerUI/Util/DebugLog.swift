//
//  DebugLog.swift
//  PlayerProto
//
//  Created by Guilherme Rambo on 29/04/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Foundation

func DebugLog(_ items: Any...) {
    #if DEBUG
        print(items)
    #endif
}
