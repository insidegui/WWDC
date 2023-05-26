//
//  DeepLink.swift
//  WWDC
//
//  Created by Guilherme Rambo on 19/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Foundation

struct DeepLink {

    struct Constants {
        static let appleHost = "developer.apple.com"
        static let nativeHost = "wwdc.io"
        static let hosts = [Self.appleHost, Self.nativeHost]
    }

    let year: Int
    let eventIdentifier: String
    let sessionNumber: Int

    let isForCurrentYear: Bool

    init?(url: URL) {
        guard let host = url.host else { return nil }
        guard Constants.hosts.contains(host) else { return nil }

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

        if let yearNumber = Int(fullYear) {
            let currentYear = "\(Calendar.current.component(.year, from: today()))"
            let currentYearDigits = String(currentYear[currentYear.index(currentYear.startIndex, offsetBy: 2)...])

            self.year = yearNumber
            eventIdentifier = "wwdc\(year)"
            isForCurrentYear = (year == currentYearDigits || year == currentYear)
        } else {
            eventIdentifier = components[components.startIndex..<components.endIndex-1].joined(separator: "-")
            isForCurrentYear = false
            self.year = 0
        }

        self.sessionNumber = sessionNumber
    }
    
    init?(from command: WWDCAppCommand) {
        guard case .revealVideo(let id) = command else { return nil }
        
        let components = id.components(separatedBy: "-")
        
        guard components.count >= 2 else { return nil }

        let event = components[components.startIndex..<components.endIndex-1].joined(separator: "-")
        let content = components[components.endIndex-1]
        
        guard let url = URL(string: "https://wwdc.io/share/\(event)/\(content)") else { return nil }
        
        self.init(url: url)
    }

}

extension URL {
    var replacingAppleDeveloperHostWithNativeHost: URL {
        guard var components = URLComponents(url: self, resolvingAgainstBaseURL: false) else { return self }
        components.host = DeepLink.Constants.nativeHost
        components.path = "/share" + components.path
        return components.url ?? self
    }
}

extension DeepLink: SessionIdentifiable {
    var sessionIdentifier: String {
        if year == 0 {
            return "\(sessionNumber)"
        } else {
            return "\(year)-\(sessionNumber)"
        }
    }
}
