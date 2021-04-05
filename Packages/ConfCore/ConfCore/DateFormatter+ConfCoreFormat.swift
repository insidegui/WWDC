//
//  DateFormatter+ConfCoreFormat.swift
//  WWDC
//
//  Created by Guilherme Rambo on 07/02/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Foundation

public let confCoreDateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"

extension DateFormatter {

    static let confCoreFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = confCoreDateFormat
        formatter.locale = Locale(identifier: "en-US")
        formatter.timeZone = TimeZone.current

        return formatter
    }()

}
