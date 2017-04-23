//
//  UserActivityRepresentable.swift
//  WWDC
//
//  Created by Guilherme Rambo on 23/04/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Foundation

protocol UserActivityRepresentable {
    var title: String { get }
    var webUrl: URL? { get }
}
