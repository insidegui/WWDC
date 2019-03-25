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
    case download = "WWDCSessionResourceTypeDownload"

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
        case "download":
            self = .download
        default:
            return nil
        }
    }
}

public class RelatedResource: Object, Decodable {
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

    // MARK: - Codable
    enum CodingKeys: String, CodingKey {
        case title, id, url, description
        case type = "resource_type"
    }

    public required convenience init(from decoder: Decoder) throws {
        self.init()

        let container = try decoder.container(keyedBy: CodingKeys.self)

        identifier = String(try container.decode(Int.self, forKey: .id))
        title = try container.decode(key: .title)
        url = try container.decode(key: .url)
        let rawType = try container.decode(String.self, forKey: .type)
        type = RelatedResourceType(rawResourceType: rawType)?.rawValue ?? ""

        descriptor = try container.decodeIfPresent(key: .description) ?? ""
    }

}

struct UnknownRelatedResource: Decodable {

    let resource: RelatedResource

    public init(from decoder: Decoder) throws {
        let id: Int = try decoder.singleValueContainer().decode()

        let resource = RelatedResource()
        resource.identifier = String(id)
        resource.type = RelatedResourceType.unknown.rawValue

        self.resource = resource
    }
}

struct ActivityRelatedResource: Decodable {

    let resource: RelatedResource

    public init(from decoder: Decoder) throws {
        let id: String = try decoder.singleValueContainer().decode()

        let resource = RelatedResource()

        resource.identifier = id
        resource.type = RelatedResourceType.session.rawValue

        self.resource = resource
    }
}
