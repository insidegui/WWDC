//
//  StorageMigrator.swift
//  ConfCore
//
//  Created by Guilherme Rambo on 29/04/18.
//  Copyright © 2018 Guilherme Rambo. All rights reserved.
//

import Foundation
import RealmSwift
import OSLog

final class StorageMigrator: Logging {

    let migration: Migration
    let oldVersion: UInt64
    static let log = makeLogger()

    private typealias SchemaVersion = UInt64
    private typealias MigrationBlock = (Migration, SchemaVersion, Logger) -> Void

    /// Migration block in `prescription.key` will be executed if the previous version is `< prescription.key`
    private let prescription: [SchemaVersion: MigrationBlock] = [
        10: migrateAlphaCleanup,
        15: migrateDownloadModelRemoval,
        31: migrateContentThumbnails,
        32: migrateSessionModels,
        34: migrateOldTranscriptModels,
        37: migrateIdentifiersWithoutReplacement,
        43: resetTracks,
        44: removeInvalidLiveAssets,
        57: resetFeaturedSections,
        59: resetTracks,
        60: resetSessionInstances
    ]

    init(migration: Migration, oldVersion: UInt64) {
        self.migration = migration
        self.oldVersion = oldVersion
    }

    private(set) var isPerforming = false

    func perform() {
        guard !isPerforming else {
            log.error("perform() called while isPerform = true")
            return
        }

        isPerforming = true
        defer { isPerforming = false }

        let migrationsToPerform = prescription.filter { oldVersion < $0.key }

        guard migrationsToPerform.count > 0 else {
            log.info("No migrations to perform")
            return
        }

        let versions = migrationsToPerform.map { $0.key }
        log.info("Will perform migrations for the following schema versions: \(String(describing: versions), privacy: .public)")

        migrationsToPerform.forEach { $0.value(migration, oldVersion, log) }
    }

    private static func migrateAlphaCleanup(with migration: Migration, oldVersion: SchemaVersion, log: Logger) {
        log.info("migrateAlphaCleanup")

        migration.deleteData(forType: "Event")
        migration.deleteData(forType: "Track")
        migration.deleteData(forType: "Room")
        migration.deleteData(forType: "Favorite")
        migration.deleteData(forType: "SessionProgress")
        migration.deleteData(forType: "Session")
        migration.deleteData(forType: "SessionInstance")
        migration.deleteData(forType: "SessionAsset")
        migration.deleteData(forType: "SessionAsset")
    }

    private static func migrateDownloadModelRemoval(with migration: Migration, oldVersion: SchemaVersion, log: Logger) {
        log.info("migrateDownloadModelRemoval")

        migration.deleteData(forType: "Download")
    }

    private static func migrateContentThumbnails(with migration: Migration, oldVersion: SchemaVersion, log: Logger) {
        log.info("migrateContentThumbnails")

        // remove cached images which might have generic session thumbs instead of the correct ones
        migration.deleteData(forType: "ImageCacheEntity")

        // delete live stream assets (some of them got duplicated during the week)
        migration.enumerateObjects(ofType: "SessionAsset") { asset, _ in
            guard let asset = asset else { return }

            if asset["rawAssetType"] as? String == SessionAssetType.liveStreamVideo.rawValue {
                migration.delete(asset)
            }
        }
    }

    private static func migrateSessionModels(with migration: Migration, oldVersion: SchemaVersion, log: Logger) {
        log.info("migrateSessionModels")

        migration.deleteData(forType: "Event")
        migration.deleteData(forType: "Track")
        migration.deleteData(forType: "ScheduleSection")
    }

    private static func migrateOldTranscriptModels(with migration: Migration, oldVersion: SchemaVersion, log: Logger) {
        log.info("migrateOldTranscriptModels")

        migration.deleteData(forType: "Transcript")
        migration.deleteData(forType: "TranscriptAnnotation")

        migration.enumerateObjects(ofType: "Session") { _, session in
            session?["transcriptIdentifier"] = ""
        }
    }

    private static func migrateIdentifiersWithoutReplacement(with migration: Migration, oldVersion: SchemaVersion, log: Logger) {
        // version 37 changed identifiers to include the event name prefix (i.e. "wwdc" or "fall")
        log.info("migrateIdentifiersWithoutReplacement")

        // add `year` to `Event` based on the event's start date
        migration.enumerateObjects(ofType: "Event") { _, event in
            guard let startDate = event?["startDate"] as? Date else {
                fatalError("Corrupt database during migration: Event.startDate must be a Date")
            }

            event?["year"] = Calendar.current.component(.year, from: startDate)
        }

        // add `wwdc` to `Session.identifier` unless it is a "fall" session
        migration.enumerateObjects(ofType: "Session") { _, session in
            guard let identifier = session?["identifier"] as? String else {
                fatalError("Corrupt database during migration: Session.identifier must be a String")
            }

            guard !identifier.contains("fall") else { return }

            let identifierWithPrefix = "wwdc" + identifier

            session?["identifier"] = identifierWithPrefix

            guard let transcriptIdentifier = session?["transcriptIdentifier"] as? String, !transcriptIdentifier.isEmpty else {
                log.debug("Session \(identifier, privacy: .public) had no transcript, skipping")
                return
            }

            session?["transcriptIdentifier"] = identifierWithPrefix
        }

        // add `wwdc` to `Transcript.identifier`
        migration.enumerateObjects(ofType: "Transcript") { _, transcript in
            guard let identifier = transcript?["identifier"] as? String else {
                fatalError("Corrupt database during migration: Transcript.identifier must be a String")
            }

            transcript?["identifier"] = "wwdc" + identifier
        }
    }

    private static func resetTracks(with migration: Migration, oldVersion: SchemaVersion, log: Logger) {
        log.info("resetTracks")

        migration.deleteData(forType: "Track")
    }

    private static func removeInvalidLiveAssets(with migration: Migration, oldVersion: SchemaVersion, log: Logger) {
        log.info("removeInvalidLiveAssets")

        // Delete invalid live streaming assets
        migration.enumerateObjects(ofType: "SessionAsset") { _, asset in
            guard let asset = asset else { return }
            guard asset["rawAssetType"] as? String == "WWDCSessionAssetTypeLiveStreamVideo" else { return }
            migration.delete(asset)
        }
    }

    private static func resetFeaturedSections(with migration: Migration, oldVersion: SchemaVersion, log: Logger) {
        log.info("resetFeaturedSections")

        // Delete all featured content
        migration.deleteData(forType: "FeaturedSection")
        migration.deleteData(forType: "FeaturedContent")
        migration.deleteData(forType: "FeaturedAuthor")
    }

    private static func resetSessionInstances(with migration: Migration, oldVersion: SchemaVersion, log: Logger) {
        migration.deleteData(forType: "SessionInstance")
    }

}
