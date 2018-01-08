//
//  DeepLink.swift
//  WWDC
//
//  Created by Guilherme Rambo on 19/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Foundation

struct DeepLink {

    private struct LinkConstants {
        static let host = "developer.apple.com"
    }

    let year: Int
    let eventIdentifier: String
    let sessionNumber: Int

    let isForCurrentYear: Bool

    var sessionIdentifier: String {
        return "\(year)-\(sessionNumber)"
    }

    init?(url: URL) {
        guard url.host == LinkConstants.host else { return nil }

        let components = url.pathComponents

        guard components.count >= 3 else { return nil }

        let yearParameter = components[components.count - 2]
        let sessionIdentifierParameter = components[components.count - 1]

        guard let sessionNumber = Int(sessionIdentifierParameter) else { return nil }

        let year: String
        let fullYear: String

        if yearParameter.count > 6 {
            year = String(yearParameter.suffix(4))
            fullYear = year
        } else {
            year = String(yearParameter.suffix(2))
            // this will only work for the next 983 years ¯\_(ツ)_/¯
            fullYear = "20\(year)"
        }

        guard let yearNumber = Int(fullYear) else { return nil }
        let currentYear = "\(Calendar.current.component(.year, from: Today()))"
        let currentYearDigits = String(currentYear[currentYear.index(currentYear.startIndex, offsetBy: 2)...])

        self.year = yearNumber
        eventIdentifier = "wwdc\(year)"
        self.sessionNumber = sessionNumber
        isForCurrentYear = (year == currentYearDigits)
    }

}
