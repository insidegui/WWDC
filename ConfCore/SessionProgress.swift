//
//  SessionProgress.swift
//  WWDC
//
//  Created by Guilherme Rambo on 11/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
import RealmSwift

/// Defines the user action of adding a session as favorite
public class SessionProgress: Object {
    
    /// Unique identifier
    public dynamic var identifier = UUID().uuidString
    
    /// When the progress was created
    public dynamic var createdAt = Date()
    
    /// When the progress was last update
    public dynamic var updatedAt = Date()
    
    /// The current position in the video (in seconds)
    public dynamic var currentPosition: Double = 0
    
    /// The session this progress is associated with
    public let session = LinkingObjects(fromType: Session.self, property: "progresses")
    
    public override class func primaryKey() -> String? {
        return "identifier"
    }
    
}

extension Session {
    
    public func setCurrentPosition(_ position: Double) {
        guard Thread.isMainThread else { return }
        
        do {
            try self.realm?.write {
                var progress: SessionProgress
                
                if let p = progresses.first {
                    progress = p
                } else {
                    progress = SessionProgress()
                    progresses.append(progress)
                }
                
                progress.currentPosition = position
                progress.updatedAt = Date()
            }
        } catch {
            NSLog("Error updating session progress: \(error)")
        }
    }
    
    public func currentPosition() -> Double {
        return progresses.first?.currentPosition ?? 0
    }
    
}
