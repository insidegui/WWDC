import Cocoa
import ConfCore

final class DownloadedContentMonitor {
    var storage: Storage?

    @MainActor
    func activate(with storage: Storage?) {
        self.storage = storage
        
        _ = NotificationCenter.default.addObserver(forName: .LocalVideoStoragePathPreferenceDidChange, object: nil, queue: nil) { _ in
            self.monitorDownloadsFolder()
        }

        updateDownloadedFlagsOfPreviouslyDownloaded()
        monitorDownloadsFolder()
    }

    fileprivate var topFolderMonitor: DTFolderMonitor!
        fileprivate var subfoldersMonitors: [DTFolderMonitor] = []
        fileprivate var existingVideoFiles = [String]()

        func syncWithFileSystem() {
            let videosPath = Preferences.shared.localVideoStorageURL.path
            updateDownloadedFlagsByEnumeratingFilesAtPath(videosPath)
        }

        private func monitorDownloadsFolder() {
            if topFolderMonitor != nil {
                topFolderMonitor.stopMonitoring()
                topFolderMonitor = nil
            }

            subfoldersMonitors.forEach({ $0.stopMonitoring() })
            subfoldersMonitors.removeAll()

            let url = Preferences.shared.localVideoStorageURL

            topFolderMonitor = DTFolderMonitor(for: url) { [unowned self] in
                self.setupSubdirectoryMonitors(on: url)

                self.updateDownloadedFlagsByEnumeratingFilesAtPath(url.path)
            }

            setupSubdirectoryMonitors(on: url)

            topFolderMonitor.startMonitoring()
        }

        private func setupSubdirectoryMonitors(on mainDirURL: URL) {
            subfoldersMonitors.forEach({ $0.stopMonitoring() })
            subfoldersMonitors.removeAll()

            mainDirURL.subDirectories.forEach { subdir in
                guard let monitor = DTFolderMonitor(for: subdir, block: { [unowned self] in
                    self.updateDownloadedFlagsByEnumeratingFilesAtPath(mainDirURL.path)
                }) else { return }

                subfoldersMonitors.append(monitor)

                monitor.startMonitoring()
            }
        }

        fileprivate func updateDownloadedFlagsOfPreviouslyDownloaded() {
            guard let storage else { return }

            let expectedOnDisk = storage.sessions.filter(NSPredicate(format: "isDownloaded == true"))
            var notPresent = [String]()

            for session in expectedOnDisk {
                if !MediaDownloadManager.shared.hasDownloadedMedia(for: session) {
                    Session.mediaDownloadVariants.forEach {
                        guard let asset = session.asset(for: $0) else { return }
                        
                        notPresent.append(asset.relativeLocalURL)
                    }
                }
            }

            storage.updateDownloadedFlag(false, forAssetsAtPaths: notPresent)
            notPresent.forEach { NotificationCenter.default.post(name: .DownloadManagerFileDeletedNotification, object: $0) }
        }

        /// Updates the downloaded status for the sessions on the database based on the existence of the downloaded video file
        ///
        /// This function is only ever called with the main destination directory, despite what the rest
        /// of the architecture might suggest. The subfolder monitors just force the entire hierarchy to be
        /// re-enumerated. This function has signifcant side effects.
        fileprivate func updateDownloadedFlagsByEnumeratingFilesAtPath(_ path: String) {
            guard let storage else { return }

            guard let enumerator = FileManager.default.enumerator(atPath: path) else { return }

            var files: [String] = []

            while let path = enumerator.nextObject() as? String {
                if enumerator.level > 1 { enumerator.skipDescendants() }
                files.append(path)
            }

            guard !files.isEmpty else { return }

            storage.updateDownloadedFlag(true, forAssetsAtPaths: files)

            files.forEach { NotificationCenter.default.post(name: .DownloadManagerFileAddedNotification, object: $0) }

            if existingVideoFiles.count == 0 {
                existingVideoFiles = files
                return
            }

            let removedFiles = existingVideoFiles.filter { !files.contains($0) }

            storage.updateDownloadedFlag(false, forAssetsAtPaths: removedFiles)

            removedFiles.forEach { NotificationCenter.default.post(name: .DownloadManagerFileDeletedNotification, object: $0) }

            // This is now the list of files
            existingVideoFiles = files
        }

        // MARK: Teardown

        deinit {
            if topFolderMonitor != nil {
                topFolderMonitor.stopMonitoring()
            }
        }
}
