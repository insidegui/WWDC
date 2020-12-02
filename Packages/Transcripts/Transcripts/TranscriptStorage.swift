//
//  TranscriptStorage.swift
//  Transcripts
//
//  Created by Guilherme Rambo on 25/05/20.
//  Copyright © 2020 Guilherme Rambo. All rights reserved.
//

import Foundation

public protocol TranscriptStorage: AnyObject {

    func previousEtag(for identifier: String) -> String?
    func store(_ transcripts: [TranscriptContent], manifest: TranscriptManifest)

}
