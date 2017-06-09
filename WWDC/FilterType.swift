//
//  FilterType.swift
//  WWDC
//
//  Created by Guilherme Rambo on 25/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Foundation

protocol FilterType {

    var identifier: String { get set }
    var isEmpty: Bool { get }
    var predicate: NSPredicate? { get }

}
