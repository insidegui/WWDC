//
//  Result.swift
//  WWDC
//
//  Created by Guilherme Rambo on 07/02/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Foundation

public enum Result<T, E: Error> {
    case success(T)
    case error(E)
}
