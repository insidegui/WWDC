//
//  CalendarHelper.swift
//  WWDC
//
//  Created by Guilherme Rambo on 13/06/16.
//  Copyright © 2016 Guilherme Rambo. All rights reserved.
//

import Foundation
import EventKit

class CalendarHelper {
    
    private var authorized = false
    private lazy var store = EKEventStore()
    
    init() {
        authorized = (EKEventStore.authorizationStatusForEntityType(.Reminder) == .Authorized)
    }
    
    private func performAuthorized(block: () -> ()) {
        guard !authorized else {
            dispatch_async(dispatch_get_main_queue(), block)
            return
        }
        
        store.requestAccessToEntityType(.Reminder) { [weak self] success, error in
            self?.authorized = success
            dispatch_async(dispatch_get_main_queue(), block)
        }
    }
    
    private var predicateForReminders: NSPredicate {
        return store.predicateForRemindersInCalendars([store.defaultCalendarForNewReminders()])
    }
    
    func registerReminderForScheduledSession(scheduledSession: ScheduledSession) {
        performAuthorized { [unowned self] in
            guard let actualSession = scheduledSession.session else { return }
            
            let reminder = EKReminder(eventStore: self.store)
            reminder.addAlarm(EKAlarm(absoluteDate: scheduledSession.startsAt))
            reminder.timeZone = NSTimeZone.systemTimeZone()
            reminder.title = actualSession.title
            reminder.calendar = self.store.defaultCalendarForNewReminders()
            
            do {
                try self.store.saveReminder(reminder, commit: true)
                WWDCDatabase.sharedDatabase.doChanges {
                    scheduledSession.calendarIdentifier = reminder.calendarItemExternalIdentifier
                }
            } catch let error as NSError {
                NSAlert(error: error).runModal()
            }
        }
    }
    
    func hasReminderForScheduledSession(scheduledSession: ScheduledSession, completionBlock: (Bool) -> ()) {
        guard authorized else {
            dispatch_async(dispatch_get_main_queue()) { completionBlock(false) }
            return
        }
        
        store.fetchRemindersMatchingPredicate(predicateForReminders) { reminders in
            dispatch_async(dispatch_get_main_queue()) {
                if let reminders = reminders where reminders.count > 0 {
                    let hasReminder = reminders.filter({ $0.calendarItemExternalIdentifier == scheduledSession.calendarIdentifier }).count > 0
                    completionBlock(hasReminder)
                } else {
                    completionBlock(false)
                }
            }
        }
    }
    
    func unregisterReminderForScheduledSession(scheduledSession: ScheduledSession) {
        guard !scheduledSession.calendarIdentifier.isEmpty else { return }
        
        store.fetchRemindersMatchingPredicate(predicateForReminders) { [weak self] reminders in
            dispatch_async(dispatch_get_main_queue()) {
                if let reminder = reminders?.filter({ $0.calendarItemExternalIdentifier == scheduledSession.calendarIdentifier }).first {
                    do {
                        try self?.store.removeReminder(reminder, commit: true)
                    } catch let error as NSError {
                        NSLog("Error deleting reminder: \(error)")
                    }
                }
            }
        }
    }
    
}