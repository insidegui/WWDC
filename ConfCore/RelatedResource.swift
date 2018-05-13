//
//  RelatedResource.swift
//  ConfCore
//
//  Created by Ben Newcombe on 21/01/2018.
//  Copyright © 2018 Guilherme Rambo. All rights reserved.
//

import Foundation
import RealmSwift

public enum RelatedResourceType: String {
    case unknown = "WWDCSessionResourceTypeUnknown"
    case guide = "WWDCSessionResourceTypeGuide"
    case documentation = "WWDCSessionResourceTypeDocumentation"
    case sampleCode = "WWDCSessionResourceTypeSampleCode"
    case session = "WWDCSessionResourceTypeSession"

    init?(rawResourceType: String) {
        switch rawResourceType {
        case "guide":
            self = .guide
        case "documentation":
            self = .documentation
        case "samplecode":
            self = .sampleCode
        case "unknown":
            self = .unknown
        default:
            return nil
        }
    }
}

public class RelatedResource: Object {
    @objc public dynamic var identifier = ""
    @objc public dynamic var title = ""
    @objc public dynamic var url = ""
    @objc public dynamic var descriptor = ""
    @objc public dynamic var type = ""
    @objc public dynamic var session: Session?

    public override class func primaryKey() -> String? {
        return "identifier"
    }

    func merge(with other: RelatedResource, in realm: Realm) {
        assert(other.identifier == identifier, "Can't merge two objects with different identifiers!")

        title = other.title
        url = other.url
        descriptor = other.descriptor
        type = other.type

        if let otherSession = other.session, let session = session {
            session.merge(with: otherSession, in: realm)
        }
    }
}
