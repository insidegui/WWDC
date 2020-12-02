//
//  TranscriptIndexingServiceProtocol.swift
//  WWDC
//
//  Created by Guilherme Rambo on 28/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Foundation

@objc public protocol TranscriptIndexingServiceProtocol: NSObjectProtocol {

    func indexTranscriptsIfNeeded(manifestURL: URL, ignoringCache: Bool, storageURL: URL, schemaVersion: UInt64)

}
