//
//  Transcript.swift
//  WWDC
//
//  Created by Guilherme Rambo on 06/06/16.
//  Copyright © 2016 Guilherme Rambo. All rights reserved.
//

import Foundation
import RealmSwift
import SwiftyJSON

class TranscriptLine: Object {
    dynamic var transcript: Transcript?
    dynamic var text = ""
    dynamic var timecode: Double = 0.0
    
    convenience required init(text: String, timecode: Double) {
        self.init()
        
        self.text = text
        self.timecode = timecode
    }
}

class Transcript: Object {
    dynamic var session: Session?
    dynamic var fullText = ""
    let lines = List<TranscriptLine>()
    
    convenience required init(json: JSON, session: Session) {
        self.init()
        
        self.session = session
        self.fullText = json["transcript"].stringValue
        
        if let annotations = json["annotations"].arrayObject as? [String], timecodes = json["timecodes"].arrayObject as? [Double] {
            for annotation in annotations {
                guard let idx = annotations.indexOf({ $0 == annotation }) else { continue }
                let line = TranscriptLine(text: annotation, timecode: timecodes[idx])
                line.transcript = self
                self.lines.append(line)
            }
        }
    }
}