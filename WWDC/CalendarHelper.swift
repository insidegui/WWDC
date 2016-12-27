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
    
    fileprivate var authorized = false
    fileprivate lazy var store = EKEventStore()
    
    init() {
        authorized = (EKEventStore.authorizationStatus(for: .reminder) == .authorized)
    }
    
    fileprivate func performAuthorized(_ block: @escaping () -> ()) {
        guard !authorized else {
            DispatchQueue.main.async(execute: block)
            return
        }
        
        store.requestAccess(to: .reminder) { [weak self] success, error in
            self?.authorized = success
            DispatchQueue.main.async(execute: block)
        }
    }
    
    fileprivate var predicateForReminders: NSPredicate {
        return store.predicateForReminders(in: [store.defaultCalendarForNewReminders()])
    }
    
    func registerReminderForScheduledSession(_ scheduledSession: ScheduledSession) {
        performAuthorized { [unowned self] in
            guard let actualSession = scheduledSession.session else { return }
            
            let reminder = EKReminder(eventStore: self.store)
            reminder.addAlarm(EKAlarm(absoluteDate: scheduledSession.startsAt as Date))
            reminder.timeZone = TimeZone.current
            reminder.title = actualSession.title
            reminder.calendar = self.store.defaultCalendarForNewReminders()
            
            do {
                try self.store.save(reminder, commit: true)
                WWDCDatabase.sharedDatabase.doChanges {
                    scheduledSession.calendarIdentifier = reminder.calendarItemExternalIdentifier
                }
            } catch let error as NSError {
                NSAlert(error: error).runModal()
            }
        }
    }
    
    func hasReminderForScheduledSession(_ scheduledSession: ScheduledSession, completionBlock: @escaping (Bool) -> ()) {
        guard authorized else {
            DispatchQueue.main.async { completionBlock(false) }
            return
        }
        
        store.fetchReminders(matching: predicateForReminders) { reminders in
            DispatchQueue.main.async {
                if let reminders = reminders, reminders.count > 0 {
                    let hasReminder = reminders.filter({ $0.calendarItemExternalIdentifier == scheduledSession.calendarIdentifier }).count > 0
                    completionBlock(hasReminder)
                } else {
                    completionBlock(false)
                }
            }
        }
    }
    
    func unregisterReminderForScheduledSession(_ scheduledSession: ScheduledSession) {
        guard !scheduledSession.calendarIdentifier.isEmpty else { return }
        
        store.fetchReminders(matching: predicateForReminders) { [weak self] reminders in
            DispatchQueue.main.async {
                if let reminder = reminders?.filter({ $0.calendarItemExternalIdentifier == scheduledSession.calendarIdentifier }).first {
                    do {
                        try self?.store.remove(reminder, commit: true)
                    } catch let error as NSError {
                        NSLog("Error deleting reminder: \(error)")
                    }
                }
            }
        }
    }
    
}
