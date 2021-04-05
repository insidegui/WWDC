//
//  EventHero.swift
//  ConfCore
//
//  Created by Guilherme Rambo on 28/05/20.
//  Copyright © 2020 Guilherme Rambo. All rights reserved.
//

import Foundation
import RealmSwift

/// Depiction of a current event.
public class EventHero: Object, Codable {

    @objc public dynamic var identifier = ""
    @objc public dynamic var title = ""
    @objc public dynamic var titleColor: String?
    @objc public dynamic var body = ""
    @objc public dynamic var bodyColor: String?
    @objc public dynamic var backgroundImage = ""
    public let textComponents = List<String>()

    public override class func primaryKey() -> String? {
        return "identifier"
    }

    public convenience required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.init()

        self.identifier = try container.decode(String.self, forKey: .identifier)
        self.title = try container.decode(String.self, forKey: .title)
        self.body = try container.decode(String.self, forKey: .body)
        self.backgroundImage = try container.decode(String.self, forKey: .backgroundImage)
        self.title = try container.decode(String.self, forKey: .title)
        self.titleColor = try container.decodeIfPresent(String.self, forKey: .titleColor)
        self.bodyColor = try container.decodeIfPresent(String.self, forKey: .bodyColor)
        self.backgroundImage = try container.decode(String.self, forKey: .backgroundImage)

        let components = try container.decodeIfPresent([String].self, forKey: .textComponents)
        components?.forEach { textComponents.append($0) }
    }

}
