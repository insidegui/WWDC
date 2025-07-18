//
//  SessionProgress.swift
//  WWDC
//
//  Created by Guilherme Rambo on 11/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
import RealmSwift
import OSLog

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

    /// When the progress was last updated
    @objc public dynamic var updatedAt = Date()

    /// The current position in the video (in seconds)
    @objc public dynamic var currentPosition: Double = 0

    /// The current position in the video, relative to the duration (from 0 to 1)
    @objc public dynamic var relativePosition: Double = 0

    /// The session this progress is associated with
    public let session = LinkingObjects(fromType: Session.self, property: "progresses")

    public override static func primaryKey() -> String? {
        return "identifier"
    }
}

extension Session: Logging {
    public static let log = makeLogger()

    private static let positionUpdateQueue = DispatchQueue(label: "PositionUpdate", qos: .background)

    public func setCurrentPosition(_ position: Double, _ duration: Double) {
        guard !duration.isNaN, !duration.isZero, !duration.isInfinite else {
            assertionFailure("Invalid duration: \(duration)")
            return
        }
        guard !position.isNaN, !position.isZero, !position.isInfinite else {
            assertionFailure("Invalid position: \(position)")
            return
        }

        guard let config = self.realm?.configuration else { return }
        let sessionId = identifier

        // Explanation for the ``isInWriteTransaction`` check:
        //
        // The context menu uses Storage.modify to update progresses
        //
        // But video playback relies on this background queue to update the position off the main thread.
        // Which was a change made here: https://github.com/insidegui/WWDC/pull/602/files
        //
        // So isInWriteTransaction == true means that the context menu is currently updating the progresses,
        // and we're already on a background queue, so we just do the update.
        //
        // I *think* that video playback should just be updated to use Storage.modify instead of relying on all this queue stuff in here.
        if self.realm?.isInWriteTransaction == true {
            Self.doSetCurrentPosition(on: self, position, duration)
            return
        }

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

        do {
            queueRealm.beginWrite()

            doSetCurrentPosition(on: session, position, duration)

            try queueRealm.commitWrite()
        } catch {
            log.error("Error updating session progress: \(String(describing: error), privacy: .public)")
        }
    }

    private static func doSetCurrentPosition(on session: Session, _ position: Double, _ duration: Double) {
        let progress: SessionProgress

        if let p = session.progresses.first {
            progress = p
        } else {
            progress = SessionProgress()
            session.progresses.append(progress)
        }

        progress.currentPosition = position
        progress.relativePosition = position / duration
        progress.updatedAt = Date()
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
            log.error("Error updating session progress: \(String(describing: error), privacy: .public)")
        }
    }

    public func currentPosition() -> Double {
        return progresses.first?.currentPosition ?? 0
    }

}
