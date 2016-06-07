//
//  NewWWDCGreeter.swift
//  WWDC
//
//  Created by Guilherme Rambo on 04/06/16.
//  Copyright © 2016 Guilherme Rambo. All rights reserved.
//

import Foundation

class NewWWDCGreeter {
    
    private lazy var automaticRefreshSuggestionAlert: NSAlert = {
        let alert = NSAlert()
        
        alert.messageText = "Another year, another WWDC"
        alert.informativeText = "Yay, It's WWDC week! Do you want to turn on automatic updates to make sure you always have the latest videos available?"
        alert.addButtonWithTitle("Yes, sure!")
        alert.addButtonWithTitle("No, thanks")
        
        return alert
    }()
    
    func presentAutomaticRefreshSuggestionIfAppropriate() {
        guard Preferences.SharedPreferences().shouldPresentAutomaticRefreshSuggestion else { return }
        
        if automaticRefreshSuggestionAlert.runModal() == 1000 {
            Preferences.SharedPreferences().automaticRefreshEnabled = true
        }
        
        Preferences.SharedPreferences().automaticRefreshSuggestionPresentedAt = NSDate()
    }
    
}

private extension Preferences {
    
    var shouldPresentAutomaticRefreshSuggestion: Bool {
        guard !Preferences.SharedPreferences().automaticRefreshEnabled else { return false }
        guard WWDCDatabase.sharedDatabase.config != nil else { return false }
        
        let isWWDCWeek = WWDCDatabase.sharedDatabase.config.isWWDCWeek
        
        if let presentedAt = automaticRefreshSuggestionPresentedAt {
            return presentedAt.numberOfDaysUntilDateTime(NSDate()) >= 200 && isWWDCWeek
        } else {
            return isWWDCWeek
        }
    }
    
}

private extension NSDate {
    func numberOfDaysUntilDateTime(toDateTime: NSDate, inTimeZone timeZone: NSTimeZone? = nil) -> Int {
        let calendar = NSCalendar.currentCalendar()
        if let timeZone = timeZone {
            calendar.timeZone = timeZone
        }
        
        var fromDate: NSDate?, toDate: NSDate?
        
        calendar.rangeOfUnit(.Day, startDate: &fromDate, interval: nil, forDate: self)
        calendar.rangeOfUnit(.Day, startDate: &toDate, interval: nil, forDate: toDateTime)
        
        let difference = calendar.components(.Day, fromDate: fromDate!, toDate: toDate!, options: [])
        
        return difference.day
    }
}