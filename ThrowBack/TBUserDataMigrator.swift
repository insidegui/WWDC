//
//  TBUserDataMigrator.swift
//  WWDC
//
//  Created by Guilherme Rambo on 13/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Foundation
import RealmSwift
import ConfCore

private struct TBConstants {
    static let legacySchemaVersion: UInt64 = 6
    static let migratedSchemaVersion: UInt64 = 2017
}

public enum TBMigrationError: Error {
    case realm(Error)

    public var localizedDescription: String {
        switch self {
        case .realm(let underlyingError):
            return "A Realm error occurred: \(underlyingError.localizedDescription)"
        }
    }
}

public enum TBMigrationResult {
    case success
    case failed(TBMigrationError)
}

public final class TBUserDataMigrator {

    private let fileURL: URL
    private var realm: Realm!
    private weak var newRealm: Realm!

    public var isPerformingMigration = false

    public static var presentedMigrationPrompt: Bool {
        get {
            if ProcessInfo.processInfo.arguments.contains("--force-migration") {
                return false
            }

            return TBPreferences.shared.presentedVersionFiveMigrationPrompt
        }
        set {
            TBPreferences.shared.presentedVersionFiveMigrationPrompt = newValue
        }
    }

    public init(legacyDatabaseFileURL: URL, newRealm: Realm) {
        self.fileURL = legacyDatabaseFileURL
        self.newRealm = newRealm
    }

    public var needsMigration: Bool {
        // the old database file is renamed after migration, if the file exists, migration is needed
        return FileManager.default.fileExists(atPath: fileURL.path)
    }

    public func performMigration(completion: @escaping (TBMigrationResult) -> Void) {
        guard !isPerformingMigration else { return }

        isPerformingMigration = true

        defer { isPerformingMigration = false }

        var legacyConfig = Realm.Configuration(fileURL: fileURL,
                                               schemaVersion: TBConstants.legacySchemaVersion,
                                               objectTypes: [])

        legacyConfig.schemaVersion = TBConstants.migratedSchemaVersion
        legacyConfig.migrationBlock = self.migrationBlock

        do {
            self.realm = try Realm(configuration: legacyConfig)

            completion(.success)
        } catch {
            completion(.failed(.realm(error)))
        }
    }

    private func migrationBlock(migration: Migration, version: UInt64) {
        self.newRealm.beginWrite()

        migration.enumerateObjects(ofType: "Session") { legacySession, _ in
            guard let migrationSession = TBSession(legacySession) else { return }

            guard let newSession = self.newRealm.object(ofType: Session.self, forPrimaryKey: migrationSession.identifier) else { return }

            if migrationSession.isFavorite {
                newSession.favorites.append(Favorite())
            }

            if !migrationSession.position.isZero || !migrationSession.relativePosition.isZero {
                let progress = SessionProgress()

                progress.currentPosition = migrationSession.position
                progress.relativePosition = migrationSession.relativePosition

                newSession.progresses.append(progress)
            }

            if let asset = newSession.assets.filter("rawAssetType == %@", SessionAssetType.hdVideo.rawValue).first {
                let basePath = TBPreferences.shared.localVideoStoragePath
                let newLocalFileURL = URL(fileURLWithPath: basePath + "/" + asset.relativeLocalURL)
                let localDirectoryURL = newLocalFileURL.deletingLastPathComponent()
                let originalLocalFileURL = URL(fileURLWithPath: basePath + "/" + newLocalFileURL.lastPathComponent)

                if FileManager.default.fileExists(atPath: originalLocalFileURL.path) {
                    do {
                        if !FileManager.default.fileExists(atPath: localDirectoryURL.path) {
                            try FileManager.default.createDirectory(at: localDirectoryURL, withIntermediateDirectories: true, attributes: nil)
                        }

                        try FileManager.default.moveItem(at: originalLocalFileURL, to: newLocalFileURL)

                        newSession.isDownloaded = true
                    } catch {
                        NSLog("Error moving downloaded file from \(originalLocalFileURL) to \(newLocalFileURL): \(error)")
                    }
                }
            }
        }

        do {
            try self.newRealm.commitWrite()
        } catch {
            NSLog("Error saving migrated realm data: \(error)")
        }

        let backupFileURL = self.fileURL.deletingPathExtension().appendingPathExtension("backup")

        do {
            try FileManager.default.moveItem(at: self.fileURL, to: backupFileURL)
        } catch {
            NSLog("Error moving backup file to \(backupFileURL)")
        }
    }

}
