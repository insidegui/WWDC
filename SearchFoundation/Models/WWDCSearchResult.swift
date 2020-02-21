//
//  WWDCSearchResult.swift
//  SearchFoundation
//
//  Created by Guilherme Rambo on 21/02/20.
//  Copyright © 2020 Guilherme Rambo. All rights reserved.
//

import Foundation

public final class WWDCSearchResult: NSObject, NSSecureCoding {

    public let identifier: String
    public let year: Int
    public let session: Int
    public let summary: String
    public let deepLink: String

    public init(identifier: String, year: Int, session: Int, summary: String, deepLink: String) {
        self.identifier = identifier
        self.year = year
        self.session = session
        self.summary = summary
        self.deepLink = deepLink

        super.init()
    }

    public static var supportsSecureCoding: Bool { true }

    private struct Keys {
        static let identifier = "i"
        static let year = "y"
        static let session = "s"
        static let summary = "t"
        static let deepLink = "l"
    }

    public func encode(with coder: NSCoder) {
        coder.encode(identifier, forKey: Keys.identifier)
        coder.encode(NSNumber(value: year), forKey: Keys.year)
        coder.encode(NSNumber(value: session), forKey: Keys.session)
        coder.encode(summary, forKey: Keys.summary)
        coder.encode(deepLink, forKey: Keys.deepLink)
    }

    public init?(coder: NSCoder) {
        guard let identifier = coder.decodeObject(of: NSString.self, forKey: Keys.identifier) as String? else { return nil }
        guard let year = coder.decodeObject(of: NSNumber.self, forKey: Keys.year) else { return nil }
        guard let session = coder.decodeObject(of: NSNumber.self, forKey: Keys.session) else { return nil }
        guard let summary = coder.decodeObject(of: NSString.self, forKey: Keys.summary) as String? else { return nil }
        guard let deepLink = coder.decodeObject(of: NSString.self, forKey: Keys.deepLink) as String? else { return nil }

        self.identifier = identifier
        self.year = year.intValue
        self.session = session.intValue
        self.summary = summary
        self.deepLink = deepLink
    }

}
