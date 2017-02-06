//
//  Transcript.swift
//  WWDC
//
//  Created by Guilherme Rambo on 06/02/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
import RealmSwift

/// Transcript is an ASCIIWWDC transcript for a WWDC session
class Transcript: Object {

    /// Unique identifier
    dynamic var identifier = ""
    
    /// The annotations the transcript contains
    let annotations = List<TranscriptAnnotation>()
    
    /// The session this transcript is for
    let session = LinkingObjects(fromType: Session.self, property: "transcript")
    
    override class func primaryKey() -> String? {
        return "identifier"
    }
    
}
