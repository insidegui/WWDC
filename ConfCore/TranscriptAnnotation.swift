//
//  TranscriptAnnotation.swift
//  WWDC
//
//  Created by Guilherme Rambo on 06/02/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
import RealmSwift

/// TranscriptAnnotation is a line within an ASCIIWWDC transcript, with its associated timestamp within the session's video
class TranscriptAnnotation: Object {

    /// The time this annotation occurs within the video
    dynamic var timecode = 0.0
    
    /// The annotation's text
    dynamic var body = ""
    
    /// The transcript this annotation is associated with
    let transcript = LinkingObjects(fromType: Transcript.self, property: "annotations")
    
}
