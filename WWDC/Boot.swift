//
//  Boot.swift
//  WWDC
//
//  Created by Guilherme Rambo on 29/06/20.
//  Copyright © 2020 Guilherme Rambo. All rights reserved.
//

import Foundation
import ConfCore
import RealmSwift
import os.log

final class Boot {

    private let log = OSLog(subsystem: "WWDC", category: String(describing: Boot.self))

    private static var isCompactOnLaunchEnabled: Bool { !UserDefaults.standard.bool(forKey: "WWDCDisableDatabaseCompression") }

    func bootstrapDependencies(then completion: @escaping (Result<(storage: Storage, syncEngine: SyncEngine), Error>) -> Void) {
        do {
            let supportPath = try PathUtil.appSupportPathCreatingIfNeeded()

            let filePath = supportPath + "/ConfCore.realm"

            var realmConfig = Realm.Configuration(fileURL: URL(fileURLWithPath: filePath))
            realmConfig.schemaVersion = Constants.coreSchemaVersion

            realmConfig.shouldCompactOnLaunch = { [unowned self] totalBytes, usedBytes in
                guard Self.isCompactOnLaunchEnabled else {
                    os_log("Database compression disabled by flag", log: self.log, type: .default)
                    return false
                }

                let oneHundredMB = 100 * 1024 * 1024

                if (totalBytes > oneHundredMB) && (Double(usedBytes) / Double(totalBytes)) < 0.8 {
                    os_log("Database will be compacted. Total bytes: %d, used bytes: %d", log: self.log, type: .default, totalBytes, usedBytes)
                    return true
                } else {
                    return false
                }
            }
            realmConfig.encryptionKey = nil
            realmConfig.migrationBlock = Storage.migrate(migration:oldVersion:)

            let client = AppleAPIClient(environment: .current)
            let cocoaHubClient = CocoaHubAPIClient(environment: .current)

            Realm.asyncOpen(configuration: realmConfig, callbackQueue: .main) { realm, error in
                guard let realm = realm else {
                    guard let error = error else { fatalError("Swift.Result FTW") }
                    completion(.failure(error))
                    return
                }

                let storage = Storage(realm)

                let syncEngine = SyncEngine(
                    storage: storage,
                    client: client,
                    cocoaHubClient: cocoaHubClient,
                    transcriptLanguage: Preferences.shared.transcriptLanguageCode
                )

                #if ICLOUD
                syncEngine.userDataSyncEngine.isEnabled = Preferences.shared.syncUserData
                #endif

                completion(.success((storage, syncEngine)))
            }
        } catch {
            os_log("Bootstrap failed: %{public}@", log: self.log, type: .fault, String(describing: error))
            completion(.failure(error))
        }
    }

}
