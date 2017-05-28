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
public class Transcript: Object {

    /// Unique identifier
    public dynamic var identifier = ""
    
    /// The annotations the transcript contains
    public let annotations = List<TranscriptAnnotation>()
    
    /// The session this transcript is for
    public let session = LinkingObjects(fromType: Session.self, property: "transcript")
    
    public override class func primaryKey() -> String? {
        return "identifier"
    }
    
}
