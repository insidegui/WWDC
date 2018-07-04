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
        case title
        case id
        case url
        case description
        case type = "resource_type"
    }

    public required convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let id = try container.decode(Int.self, forKey: .id)
        let title = try container.decode(String.self, forKey: .title)
        let url = try container.decode(String.self, forKey: .url)
        let rawType = try container.decode(String.self, forKey: .type)

        self.init()

        self.identifier = String(id)
        self.title = title
        self.url = url
        self.type = RelatedResourceType(rawResourceType: rawType)?.rawValue ?? ""

        if let description = try? container.decode(String.self, forKey: .description) {
            self.descriptor = description
        }
    }

}

struct UnknownRelatedResource: Decodable {

    let resource: RelatedResource

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        let id = try container.decode(Int.self)

        let resource = RelatedResource()

        resource.identifier = String(id)
        resource.type = RelatedResourceType.unknown.rawValue

        self.resource = resource
    }
}

struct ActivityRelatedResource: Decodable {

    let resource: RelatedResource

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        let id = try container.decode(String.self)

        let resource = RelatedResource()

        resource.identifier = id
        resource.type = RelatedResourceType.session.rawValue

        self.resource = resource
    }
}
