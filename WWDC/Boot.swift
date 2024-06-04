//
//  Boot.swift
//  WWDC
//
//  Created by Guilherme Rambo on 29/06/20.
//  Copyright © 2020 Guilherme Rambo. All rights reserved.
//

import Cocoa
import ConfCore
import RealmSwift
import OSLog

final class Boot: Logging {

    struct BootstrapError: LocalizedError {
        var localizedDescription: String
        var code: Code = .unknown

        enum Code: Int {
            case unknown
            case unusableStorage
            case dataReset
        }

        static let dataReset = BootstrapError(localizedDescription: "", code: .dataReset)

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

    static let log = makeLogger()

    private static var isCompactOnLaunchEnabled: Bool {
        !UserDefaults.standard.bool(forKey: "WWDCDisableDatabaseCompression")
    }

    func bootstrapDependencies(readOnly: Bool = false, then completion: @escaping (Result<(storage: Storage, syncEngine: SyncEngine), BootstrapError>) -> Void) {
        guard !confirmDataResetIfNeeded() else {
            resetLocalStorage()
            completion(.failure(.dataReset))
            return
        }

        WWDCAgentRemover.removeWWDCAgentIfNeeded()

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
                        self.log.log("Database compression disabled by flag")
                        return false
                    }
                    
                    let oneHundredMB = 100 * 1024 * 1024
                    
                    if (totalBytes > oneHundredMB) && (Double(usedBytes) / Double(totalBytes)) < 0.8 {
                        self.log.log("Database will be compacted. Total bytes: \(totalBytes), used bytes: \(usedBytes)")
                        return true
                    } else {
                        self.log.log("Database will not be compacted. Total bytes: \(totalBytes), used bytes: \(usedBytes)")
                        return false
                    }
                }
            }
            realmConfig.encryptionKey = nil
            realmConfig.migrationBlock = Storage.migrate(migration:oldVersion:)

            let client = AppleAPIClient(environment: .current)

            Realm.asyncOpen(configuration: realmConfig) { result in
                switch result {
                case .success(let realm):
                    let storage = Storage(realm)

                    let syncEngine = SyncEngine(
                        storage: storage,
                        client: client,
                        transcriptLanguage: Preferences.shared.transcriptLanguageCode
                    )

                    #if ICLOUD
                    syncEngine.userDataSyncEngine?.isEnabled = ConfCoreCapabilities.isCloudKitEnabled
                    #endif

                    #if DEBUG
                    if UserDefaults.standard.bool(forKey: "WWDCSimulateDatabaseLoadingHang") {
                        self.log.log("### WWDCSimulateDatabaseLoadingHang enabled, if the app is being slow to start, that's why! ###")
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
            log.fault("Bootstrap failed: \(String(describing: error), privacy: .public)")
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
            log.error("Storage path at \(url.path, privacy: .public) failed test: \(String(describing: error), privacy: .public)")
            return false
        }
    }

    // MARK: - Hold Down Option for Reset

    /// Returns `true` if the prompt was shown and the user confirmed the data reset.
    private func confirmDataResetIfNeeded() -> Bool {
        guard NSEvent.modifierFlags.contains(.option) else { return false }

        let supportURL = URL(fileURLWithPath: PathUtil.appSupportPathAssumingExisting)

        guard FileManager.default.fileExists(atPath: supportURL.path) else {
            return false
        }

        let confirmation = NSAlert()
        confirmation.messageText = "Reset App Data"

        confirmation.informativeText = """
        Reset local database and preferences?

        If you're having issues with app hangs, slowdowns, or incorrect data, resetting the local database might help.

        Local data including favorites and bookmarks will be permanently deleted.
        """

        if Preferences.shared.syncUserData {
            confirmation.informativeText += "\n\nYour data will be restored from iCloud when the app restarts."
        }

        confirmation.addButton(withTitle: "Cancel")

        confirmation.addButton(withTitle: "Reset")
        // Tried this for the Reset button, but it looks ugly in Dark Mode for some reason :/
        // hasDestructiveAction = true

        let response = confirmation.runModal()

        guard response == .alertSecondButtonReturn else { return false }

        return true
    }

    private func resetLocalStorage() {
        Task { @MainActor in
            do {
                UserDataSyncEngine.resetLocalMetadata()
                
                let supportURL = URL(fileURLWithPath: PathUtil.appSupportPathAssumingExisting)

                try await NSWorkspace.shared.recycle([supportURL])

                let relaunch = NSAlert()
                relaunch.messageText = "Database Reset"
                relaunch.informativeText = "Would you like to relaunch the app now?"
                relaunch.addButton(withTitle: "Relaunch")
                relaunch.addButton(withTitle: "Quit")

                if relaunch.runModal() == .alertFirstButtonReturn {
                    try NSApplication.shared.relaunch()
                } else {
                    NSApplication.shared.terminate(self)
                }
            } catch {
                WWDCAlert.show(with: error)
            }
        }
    }

}

extension NSApplication {
    // Credit: Andy Kim (PFMoveApplication)
    func relaunch(at path: String = Bundle.main.bundlePath) throws {
        let pid = ProcessInfo.processInfo.processIdentifier

        let xattrScript = "/usr/bin/xattr -d -r com.apple.quarantine \(path)"
        let script = "(while /bin/kill -0 \(pid) >&/dev/null; do /bin/sleep 0.1; done; \(xattrScript); /usr/bin/open \(path)) &"

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/sh")
        proc.arguments = [
            "-c",
            script
        ]

        try proc.run()

        exit(0)
    }
}

extension NSWorkspace: @unchecked Sendable { }
