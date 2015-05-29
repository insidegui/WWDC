//
//  Video.swift
//  WWDC
//
//  Created by Guilherme Rambo on 18/04/15.
//  Copyright (c) 2015 Guilherme Rambo. All rights reserved.
//

import Foundation

let SessionProgressDidChangeNotification = "SessionProgressDidChangeNotification"
let SessionFavoriteStatusDidChangeNotification = "SessionFavoriteStatusDidChangeNotification"

struct Session {
    
    var date: String?
    var description: String
    var focus: [String]
    var id: Int
    var slides: String?
    var title: String
    var track: String
    var url: String
    var year: Int
    var hd_url: String?
    
    var progress: Double {
        get {
            return DataStore.SharedStore.fetchSessionProgress(self)
        }
        set {
            DataStore.SharedStore.putSessionProgress(self, progress: newValue)
            NSNotificationCenter.defaultCenter().postNotificationName(SessionProgressDidChangeNotification, object: self.progressKey)
        }
    }
    
    var currentPosition: Double {
        get {
            return DataStore.SharedStore.fetchSessionCurrentPosition(self)
        }
        set {
            DataStore.SharedStore.putSessionCurrentPosition(self, position: newValue)
        }
    }
    
    var favorite: Bool {
        get {
            return DataStore.SharedStore.fetchSessionIsFavorite(self)
        }
        set {
            DataStore.SharedStore.putSessionIsFavorite(self, favorite: newValue)
            NSNotificationCenter.defaultCenter().postNotificationName(SessionFavoriteStatusDidChangeNotification, object: self.uniqueKey)
        }
    }
    
    var shareURL: String {
        get {
            return "wwdc://\(year)/\(id)"
        }
    }
    
    var uniqueKey: String {
        get {
            return "\(year)-\(id)"
        }
    }
    var progressKey: String {
        get {
            return "\(uniqueKey)-progress"
        }
    }
    var currentPositionKey: String {
        get {
            return "\(uniqueKey)-currentPosition"
        }
    }
    
    init(date: String?, description: String, focus: [String], id: Int, slides: String?, title: String, track: String, url: String, year: Int, hd_url: String?)
    {
        self.date = date
        self.description = description
        self.focus = focus
        self.id = id
        self.slides = slides
        self.title = title
        self.track = track
        self.url = url
        self.year = year
        self.hd_url = hd_url
    }
    
    func setProgressWithoutSendingNotification(progress: Double) {
        DataStore.SharedStore.putSessionProgress(self, progress: progress)
    }
    
    func setFavoriteWithoutSendingNotification(favorite: Bool) {
        DataStore.SharedStore.putSessionIsFavorite(self, favorite: favorite)
    }
    
    func shareURL(time: Double) -> String {
        return "\(shareURL)?t=\(time)"
    }
    
}

extension Session: Equatable {}

func ==(lhs: Session, rhs: Session) -> Bool {
    return lhs.uniqueKey == rhs.uniqueKey
}