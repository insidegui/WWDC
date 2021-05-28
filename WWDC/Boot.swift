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

    struct BootstrapError: LocalizedError {
        var localizedDescription: String
        var code: Code = .unknown

        enum Code: Int {
            case unknown
            case unusableStorage
        }

        static func unusableStorage(at url: URL) -> Self {
            BootstrapError(
                localizedDescription: "The directory used to store this app's database is not accessible. Ensure that your user has permission to read and write at \(url.path).",
                code: .unusableStorage
            )
        }

        static func generic(message: String = "Failed to open the app's database.", error: Error) -> Self {
            let description = (error as NSError).userInfo[NSLocalizedRecoverySuggestionErrorKey] ?? String(describing: error)
            return BootstrapError(localizedDescription: "\(message).\n\(description)")
        }
    }

    private let log = OSLog(subsystem: "WWDC", category: String(describing: Boot.self))

    private static var isCompactOnLaunchEnabled: Bool {
        !UserDefaults.standard.bool(forKey: "WWDCDisableDatabaseCompression")
    }

    func bootstrapDependencies(readOnly: Bool = false, then completion: @escaping (Result<(storage: Storage, syncEngine: SyncEngine), BootstrapError>) -> Void) {
        do {
            let supportPath = try PathUtil.appSupportPathCreatingIfNeeded()
            let filePath = supportPath + "/ConfCore.realm"
            let url = URL(fileURLWithPath: filePath)

            if !readOnly {
                guard isUsableStorage(at: url) else {
                    completion(.failure(.unusableStorage(at: url)))
                    return
                }
            }

            var realmConfig = Realm.Configuration(fileURL: url, readOnly: readOnly)
            realmConfig.schemaVersion = Constants.coreSchemaVersion

            if !readOnly {
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
            }
            realmConfig.encryptionKey = nil
            realmConfig.migrationBlock = Storage.migrate(migration:oldVersion:)

            let client = AppleAPIClient(environment: .current)
            let cocoaHubClient = CocoaHubAPIClient(environment: .current)

            Realm.asyncOpen(configuration: realmConfig) { result in
                switch result {
                case .success(let realm):
                    let storage = Storage(realm)

                    let syncEngine = SyncEngine(
                        storage: storage,
                        client: client,
                        cocoaHubClient: cocoaHubClient,
                        transcriptLanguage: Preferences.shared.transcriptLanguageCode
                    )

                    #if ICLOUD
                    syncEngine.userDataSyncEngine?.isEnabled = ConfCoreCapabilities.isCloudKitEnabled
                    #endif

                    #if DEBUG
                    if UserDefaults.standard.bool(forKey: "WWDCSimulateDatabaseLoadingHang") {
                        os_log("### WWDCSimulateDatabaseLoadingHang enabled, if the app is being slow to start, that's why! ###", log: self.log, type: .default)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                            completion(.success((storage, syncEngine)))
                        }
                        return
                    }
                    #endif

                    completion(.success((storage, syncEngine)))
                case .failure(let error):
                    completion(.failure(.generic(error: error)))
                }
            }
        } catch {
            os_log("Bootstrap failed: %{public}@", log: self.log, type: .fault, String(describing: error))
            completion(.failure(.generic(error: error)))
        }
    }

    private func isUsableStorage(at url: URL) -> Bool {
        do {
            let manager = FileManager.default
            let testFileURL = url.deletingLastPathComponent().appendingPathComponent(".wwdctest")

            // Test writing
            let data = Data("test".utf8)
            try data.write(to: testFileURL)

            // Test reading
            _ = try Data(contentsOf: testFileURL)

            // Delete
            try manager.removeItem(at: testFileURL)

            return true
        } catch {
            os_log("Storage path at %{public}@ failed test: %{public}@", log: self.log, type: .error, url.path, String(describing: error))
            return false
        }
    }

}
