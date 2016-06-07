//
//  TranscriptAdapter.swift
//  WWDC
//
//  Created by Guilherme Rambo on 07/06/16.
//  Copyright © 2016 Guilherme Rambo. All rights reserved.
//

import Foundation
import SwiftyJSON

class TranscriptLineAdapter: JSONAdapter {
    
    typealias ModelType = TranscriptLine
    
    static func adapt(json: JSON) -> ModelType {
        let line = TranscriptLine()
        
        line.timecode = json["timecode"].doubleValue
        line.text = json["annotation"].stringValue
        
        return line
    }
    
}

class TranscriptAdapter: JSONAdapter {
    
    typealias ModelType = Transcript
    
    static func adapt(json: JSON) -> ModelType {
        let transcript = Transcript()
        
        transcript.fullText = json["transcript"].stringValue
        
        if let annotations = json["annotations"].arrayObject as? [String], timecodes = json["timecodes"].arrayObject as? [Double] {
            let transcriptData = annotations.map { annotations.indexOf($0)! >= timecodes.count ? nil : JSON(["annotation": $0, "timecode": timecodes[annotations.indexOf($0)!]]) }.filter({ $0 != nil }).map({$0!})
            
            transcriptData.map(TranscriptLineAdapter.adapt).forEach { line in
                line.transcript = transcript
                transcript.lines.append(line)
            }
        }
        
        return transcript
    }
    
}