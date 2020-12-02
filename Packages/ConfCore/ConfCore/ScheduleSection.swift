//
//  ScheduleSection.swift
//  WWDC
//
//  Created by Guilherme Rambo on 13/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
import RealmSwift

/// A section from the schedule, representing a time slot of the conference
public final class ScheduleSection: Object {

    @objc public dynamic var identifier: String = ""
    @objc public dynamic var eventIdentifier: String = ""
    @objc public dynamic var representedDate: Date = .distantPast
    public let instances = List<SessionInstance>()

    public override class func primaryKey() -> String {
        return "identifier"
    }

    internal static var identifierFormatter: DateFormatter {
        let f = DateFormatter()

        f.dateFormat = "MM-dd-yyyy'@'HH:mm"

        return f
    }

}
