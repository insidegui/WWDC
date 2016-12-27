//
//  ArrayExtensions.swift
//  WWDC
//
//  Created by Guilherme Rambo on 19/04/15.
//  Copyright (c) 2015 Guilherme Rambo. All rights reserved.
//

import Foundation

extension RangeReplaceableCollection where Iterator.Element: Equatable {
    mutating func remove(_ object: Iterator.Element) {
        guard let index = index(of: object)
            else { return }

        self.remove(at: index)
    }
}
