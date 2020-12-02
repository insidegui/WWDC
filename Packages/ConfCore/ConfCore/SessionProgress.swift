//
//  SessionProgress.swift
//  WWDC
//
//  Created by Guilherme Rambo on 11/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
import RealmSwift
import os.log

/// Defines the user action of adding a session as favorite
public final class SessionProgress: Object, HasCloudKitFields, SoftDeletable {

    /// CloudKit system data
    @objc public dynamic var ckFields = Data()

    /// Soft delete (for syncing)
    @objc public dynamic var isDeleted: Bool = false

    /// Unique identifier
    @objc public dynamic var identifier = UUID().uuidString

    /// When the progress was created
    @objc public dynamic var createdAt = Date()

    /// When the progress was last update
    @objc public dynamic var updatedAt = Date()

    /// The current position in the video (in seconds)
    @objc public dynamic var currentPosition: Double = 0

    /// The current position in the video, relative to the duration (from 0 to 1)
    @objc public dynamic var relativePosition: Double = 0

    /// The session this progress is associated with
    public let session = LinkingObjects(fromType: Session.self, property: "progresses")

    public override class func primaryKey() -> String? {
        return "identifier"
    }
}

extension Session {

    private static let positionUpdateQueue = DispatchQueue(label: "PositionUpdate", qos: .background)

    public func setCurrentPosition(_ position: Double, _ duration: Double) {
        guard let config = self.realm?.configuration else { return }
        let sessionId = identifier

        Self.positionUpdateQueue.async {
            Self.onQueueSetCurrentPosition(configuration: config, for: sessionId, position, duration)
        }
    }

    public static func setCurrentPosition(for sessionId: String, in storage: Storage, position: Double, duration: Double) {
        Self.positionUpdateQueue.async {
            Self.onQueueSetCurrentPosition(configuration: storage.realm.configuration, for: sessionId, position, duration)
        }
    }

    private static func onQueueSetCurrentPosition(configuration: Realm.Configuration, for sessionId: String, _ position: Double, _ duration: Double) {
        guard let queueRealm = try? Realm(configuration: configuration, queue: positionUpdateQueue) else {
            assertionFailure("Failed to initialize background realm for session progress update")
            return
        }

        guard let session = queueRealm.object(ofType: Session.self, forPrimaryKey: sessionId) else { return }

        guard !duration.isNaN, !duration.isZero, !duration.isInfinite else { return }
        guard !position.isNaN, !position.isZero, !position.isInfinite else { return }

        do {
            queueRealm.beginWrite()

            var progress: SessionProgress

            if let p = session.progresses.first {
                progress = p
            } else {
                progress = SessionProgress()
                session.progresses.append(progress)
            }

            progress.currentPosition = position
            progress.relativePosition = position / duration
            progress.updatedAt = Date()

            try queueRealm.commitWrite()
        } catch {
            os_log("Error updating session progress: %{public}@", log: .default, type: .error, String(describing: error))
        }
    }

    public func resetProgress() {
        guard let realm = realm else { return }
        do {
            let mustCommit: Bool

            if !realm.isInWriteTransaction {
                realm.beginWrite()
                mustCommit = true
            } else {
                mustCommit = false
            }

            progresses.removeAll()

            if mustCommit { try realm.commitWrite() }
        } catch {
            os_log("Error updating session progress: %{public}@", log: .default, type: .error, String(describing: error))
        }
    }

    public func currentPosition() -> Double {
        return progresses.first?.currentPosition ?? 0
    }

}
