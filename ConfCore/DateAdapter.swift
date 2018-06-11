//
//  DateAdapter.swift
//  WWDC
//
//  Created by Guilherme Rambo on 07/02/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Foundation

public let confCoreDateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"

final class DateAdapter: Adapter {
    typealias InputType = String
    typealias OutputType = Date

    func adapt(_ input: String) -> Result<Date, AdapterError> {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en-US")
        formatter.timeZone = .current

        if let date = formatter.date(from: input) {
            return .success(date)
        } else {
            return .error(.invalidData)
        }
    }
}

final class DateTimeAdapter: Adapter {
    typealias InputType = String
    typealias OutputType = Date

    func adapt(_ input: String) -> Result<Date, AdapterError> {
        let formatter = DateFormatter()
        formatter.dateFormat = confCoreDateFormat
        formatter.locale = Locale(identifier: "en-US")
        formatter.timeZone = .current

        if let date = formatter.date(from: input) {
            return .success(date)
        } else {
            return .error(.invalidData)
        }
    }
}
