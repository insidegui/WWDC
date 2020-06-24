//
//  CodeSnippet.swift
//  ConfCore
//
//  Created by Guilherme Rambo on 24/06/20.
//  Copyright © 2020 Guilherme Rambo. All rights reserved.
//

import Foundation
import RealmSwift

public enum SnippetLanguage: String, Codable {
    case swift
    case xml
    case json
    case objectiveC = "objectivec"
}

/// Specifies a code snippet associated with a specific timestamp within a session.
public class CodeSnippet: Object {

    /// Title
    @objc public dynamic var title = ""

    /// The identifier for the session this snippet is associated with
    @objc public dynamic var sessionIdentifier = ""

    /// HTML representation of the code
    @objc public dynamic var code: String = ""

    /// Do I really need to explain it?
    @objc public dynamic var startTimeSeconds = 0

    /// Do I really need to explain it?
    @objc public dynamic var endTimeSeconds = 0

    /// The name of the language the snippet is in
    @objc dynamic var rawLanguage = ""

    public var language: SnippetLanguage? { SnippetLanguage(rawValue: rawLanguage) }

    /// The session this snippet is associated with
    public let session = LinkingObjects(fromType: Session.self, property: "codeSnippets")

    public override static func primaryKey() -> String? {
        return "identifier"
    }

}
