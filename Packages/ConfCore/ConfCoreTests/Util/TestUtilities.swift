//
//  TestUtilities.swift
//  ConfCoreTests
//
//  Created by Allen Humphreys on 8/3/18.
//  Copyright © 2018 Guilherme Rambo. All rights reserved.
//

import XCTest

func tryOrXCTFail<T>(_ thingToTry: @autoclosure () throws -> T, line: Int = #line) -> T {
    do {
        return try thingToTry()
    } catch {
        XCTFail("\(#function) called at line \(line) failed to produce type <\(T.self)> with error: \(error)")
        fatalError()
    }
}
