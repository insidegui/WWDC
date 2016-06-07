//
//  Transcript.swift
//  WWDC
//
//  Created by Guilherme Rambo on 06/06/16.
//  Copyright © 2016 Guilherme Rambo. All rights reserved.
//

import Foundation
import RealmSwift

class TranscriptLine: Object {
    
    dynamic var transcript: Transcript?
    
    dynamic var text = ""
    dynamic var timecode: Double = 0.0
    
}

class Transcript: Object {
    
    dynamic var session: Session?
    dynamic var fullText = ""
    
    let lines = List<TranscriptLine>()
    
}