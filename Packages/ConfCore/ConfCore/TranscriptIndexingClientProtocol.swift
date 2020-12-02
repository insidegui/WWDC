//
//  TranscriptIndexingClientProtocol.swift
//  ConfCore
//
//  Created by Guilherme Rambo on 27/05/20.
//  Copyright © 2020 Guilherme Rambo. All rights reserved.
//

import Foundation

@objc public protocol TranscriptIndexingClientProtocol: NSObjectProtocol {

    func transcriptIndexingStarted()
    func transcriptIndexingProgressDidChange(_ progress: Float)
    func transcriptIndexingStopped()

}
