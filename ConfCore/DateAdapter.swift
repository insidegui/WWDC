//
//  DateAdapter.swift
//  WWDC
//
//  Created by Guilherme Rambo on 07/02/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Foundation

final class DateAdapter: Adapter {
    typealias InputType = String
    typealias OutputType = Date
    
    func adapt(_ input: String) -> Result<Date, AdapterError> {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale.current
        formatter.timeZone = TimeZone.current
        
        if let date = formatter.date(from: input) {
            return .success(date)
        } else {
            return .error(.invalidData)
        }
    }
}
