//
//  EventHero.swift
//  ConfCore
//
//  Created by Guilherme Rambo on 28/05/20.
//  Copyright © 2020 Guilherme Rambo. All rights reserved.
//

import Foundation
import RealmSwift

/// Depiction of a current event for which the schedule is not available (a "coming soon" type page)
public class EventHero: Object, Codable {

    @objc public dynamic var identifier = ""
    @objc public dynamic var title = ""
    @objc public dynamic var titleColor: String?
    @objc public dynamic var body = ""
    @objc public dynamic var bodyColor: String?
    @objc public dynamic var backgroundImage = ""

    public override class func primaryKey() -> String? {
        return "identifier"
    }

}
