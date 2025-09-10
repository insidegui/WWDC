//
//  ConfUIFoundation.swift
//  ConfUIFoundation
//
//  Created by Guilherme Rambo on 03/06/20.
//  Copyright © 2020 Guilherme Rambo. All rights reserved.
//

@_exported import Cocoa

private final class _StubForBundleInit { }

extension Bundle {
    static let confUIFoundation = Bundle(for: _StubForBundleInit.self)
}

let kConfUIFoundationSubsystem = "io.wwdc.ConfUIFoundation"
