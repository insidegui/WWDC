//
//  TranscriptsJSONAdapter.swift
//  WWDC
//
//  Created by Guilherme Rambo on 20/02/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Foundation
import SwiftyJSON

private enum TranscriptKeys: String, JSONSubscriptType {
    case year, number, timecodes, annotations

    case fullText = "transcript"

    var jsonKey: JSONKey {
        return JSONKey.key(rawValue)
    }
}

final class TranscriptsJSONAdapter: Adapter {

    typealias InputType = JSON
    typealias OutputType = Transcript

    func adapt(_ input: JSON) -> Result<Transcript, AdapterError> {
        guard let year = input[TranscriptKeys.year].int else {
            return .error(.missingKey(TranscriptKeys.year))
        }

        guard let number = input[TranscriptKeys.number].int else {
            return .error(.missingKey(TranscriptKeys.number))
        }

        guard let timecodes = input[TranscriptKeys.timecodes].array else {
            return .error(.missingKey(TranscriptKeys.timecodes))
        }

        guard let annotationsJson = input[TranscriptKeys.annotations].array else {
            return .error(.missingKey(TranscriptKeys.annotations))
        }

        let annotations: [TranscriptAnnotation] = zip(timecodes, annotationsJson).compactMap { time, body in
            guard let time = time.double, let body = body.string else { return nil }

            let annotation = TranscriptAnnotation()

            annotation.timecode = time
            annotation.body = body

            return annotation
        }

        let transcript = Transcript()

        transcript.identifier = "\(year)-\(number)"
        transcript.fullText = input[TranscriptKeys.fullText].string ?? ""
        transcript.annotations.append(objectsIn: annotations)

        return .success(transcript)
    }

}
