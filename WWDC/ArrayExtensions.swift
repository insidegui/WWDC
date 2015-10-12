//
//  ArrayExtensions.swift
//  WWDC
//
//  Created by Guilherme Rambo on 19/04/15.
//  Copyright (c) 2015 Guilherme Rambo. All rights reserved.
//

import Foundation

extension RangeReplaceableCollectionType where Generator.Element: Equatable {
    mutating func remove(object: Generator.Element) {
        guard let index = indexOf(object)
            else { return }

        self.removeAtIndex(index)
    }
}