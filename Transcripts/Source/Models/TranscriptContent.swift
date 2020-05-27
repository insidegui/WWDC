//
//  TranscriptContent.swift
//  Transcripts
//
//  Created by Guilherme Rambo on 25/05/20.
//  Copyright © 2020 Guilherme Rambo. All rights reserved.
//

import Foundation

public struct TranscriptContent: Hashable, Decodable {

    public struct Line: Hashable, Decodable {
        public let time: Int
        public let text: String

        public init(from decoder: Decoder) throws {
            var container = try decoder.unkeyedContainer()

            var decodedTime: Int?
            var decodedText: String?

            while !container.isAtEnd {
                if let time = try? container.decode(Int.self) {
                    decodedTime = time
                } else if let text = try? container.decode(String.self) {
                    decodedText = text
                } else {
                    throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: [], debugDescription: "A transcript line has to be an array with an Int and a String"))
                }
            }

            guard let time = decodedTime, let text = decodedText else {
                throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: [], debugDescription: "A transcript line has to be an array with an Int and a String"))
            }

            self.time = time
            self.text = text
        }
    }

    public let identifier: String
    public let lines: [Line]

    private struct CodingKeys: CodingKey {
        var stringValue: String

        init?(stringValue: String) {
            self.stringValue = stringValue
        }

        var intValue: Int?

        init?(intValue: Int) {
            self.intValue = intValue
            self.stringValue = String(intValue)
        }

        static let transcript = CodingKeys(stringValue: "transcript")!
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        guard let firstKey = container.allKeys.first else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: [], debugDescription: "Missing nested root session ID key"))
        }

        let child = try container.nestedContainer(keyedBy: CodingKeys.self, forKey: firstKey)

        var linesContainer = try child.nestedUnkeyedContainer(forKey: .transcript)

        var lines: [Line] = []

        while !linesContainer.isAtEnd {
            let line = try linesContainer.decode(Line.self)
            lines.append(line)
        }

        self.identifier = firstKey.stringValue
        self.lines = lines
    }

}
