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
public class Transcript: Object, Decodable {

    /// Unique identifier
    @objc public dynamic var identifier = ""

    /// The annotations the transcript contains
    public let annotations = List<TranscriptAnnotation>()

    /// The text of the transcript
    @objc public dynamic var fullText = ""

    @objc public dynamic var etag: String?

    public override class func primaryKey() -> String? {
        return "identifier"
    }

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case year, number, timecodes, annotations, transcript
    }

    public required convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let year = try container.decode(Int.self, forKey: .year)
        let number = try container.decode(Int.self, forKey: .number)
        let timecodes = try container.decode(Array<Double>.self, forKey: .timecodes)
        let annotationsJSON = try container.decode(Array<String>.self, forKey: .annotations)
        let transcript = try container.decodeIfPresent(String.self, forKey: .transcript) ?? ""

        let annotations: [TranscriptAnnotation] = zip(timecodes, annotationsJSON).compactMap { time, body in
            let annotation = TranscriptAnnotation()

            annotation.timecode = time
            annotation.body = body

            return annotation
        }

        self.init()

        self.identifier = "wwdc\(year)-\(number)"
        self.fullText = transcript
        self.annotations.append(objectsIn: annotations)
    }
}
