//
//  NewWWDCGreeter.swift
//  WWDC
//
//  Created by Guilherme Rambo on 04/06/16.
//  Copyright © 2016 Guilherme Rambo. All rights reserved.
//

import Foundation

class NewWWDCGreeter {
    
    fileprivate lazy var automaticRefreshSuggestionAlert: NSAlert = {
        let alert = NSAlert()
        
        alert.messageText = "Another year, another WWDC"
        alert.informativeText = "Yay, It's WWDC week! Do you want to turn on automatic updates to make sure you always have the latest videos available?"
        alert.addButton(withTitle: "Yes, sure!")
        alert.addButton(withTitle: "No, thanks")
        
        return alert
    }()
    
    func presentAutomaticRefreshSuggestionIfAppropriate() {
        guard Preferences.SharedPreferences().shouldPresentAutomaticRefreshSuggestion else { return }
        
        if automaticRefreshSuggestionAlert.runModal() == 1000 {
            Preferences.SharedPreferences().automaticRefreshEnabled = true
        }
        
        Preferences.SharedPreferences().automaticRefreshSuggestionPresentedAt = Date()
    }
    
}

private extension Preferences {
    
    var shouldPresentAutomaticRefreshSuggestion: Bool {
        guard !Preferences.SharedPreferences().automaticRefreshEnabled else { return false }
        guard WWDCDatabase.sharedDatabase.config != nil else { return false }
        
        let isWWDCWeek = WWDCDatabase.sharedDatabase.config.isWWDCWeek
        
        if let presentedAt = automaticRefreshSuggestionPresentedAt {
            return presentedAt.numberOfDaysUntilDateTime(Date()) >= 200 && isWWDCWeek
        } else {
            return isWWDCWeek
        }
    }
    
}

private extension Date {
    func numberOfDaysUntilDateTime(_ toDateTime: Date, inTimeZone timeZone: TimeZone? = nil) -> Int {
        var calendar = NSCalendar.current
        if let timeZone = timeZone {
            calendar.timeZone = timeZone
        }
        
        var fromDate: NSDate?, toDate: NSDate?
        
        (calendar as NSCalendar).range(of: .day, start: &fromDate, interval: nil, for: self)
        (calendar as NSCalendar).range(of: .day, start: &toDate, interval: nil, for: toDateTime)
        
        guard fromDate != nil, toDate != nil else {
            return 0
        }
        
        let difference = calendar.dateComponents(Set([Calendar.Component.day]), from: fromDate as! Date, to: toDate as! Date)
        
        return difference.day ?? 0
    }
}
