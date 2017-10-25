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
    @objc public dynamic var identifier = ""

    /// The annotations the transcript contains
    public let annotations = List<TranscriptAnnotation>()

    /// The text of the transcript
    @objc public dynamic var fullText = ""

    public override class func primaryKey() -> String? {
        return "identifier"
    }

}
