import Cocoa
import ConfCore
import OSLog

final class DownloadedContentMonitor: Logging {
    static let log = makeLogger()

    var storage: Storage?

    @MainActor
    func activate(with storage: Storage?) {
        log.debug(#function)

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
        log.debug(#function)

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
        guard let storage else {
            log.warning("Asked to update downloaded flags without the storage being available")
            return
        }

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

        if !notPresent.isEmpty {
            log.info("Found \(notPresent.count, privacy: .public) media files which had the downloaded flag, but are no longer present")

            storage.updateDownloadedFlag(false, forAssetsAtPaths: notPresent)

            notPresent.forEach { NotificationCenter.default.post(name: .DownloadManagerFileDeletedNotification, object: $0) }
        }
    }

    /// Updates the downloaded status for the sessions on the database based on the existence of the downloaded video file
    ///
    /// This function is only ever called with the main destination directory, despite what the rest
    /// of the architecture might suggest. The subfolder monitors just force the entire hierarchy to be
    /// re-enumerated. This function has signifcant side effects.
    fileprivate func updateDownloadedFlagsByEnumeratingFilesAtPath(_ rootPath: String) {
        guard let storage else {
            log.warning("Asked to update downloaded flags without the storage being available")
            return
        }

        let rootURL = URL(fileURLWithPath: rootPath)

        guard let enumerator = FileManager.default.enumerator(at: rootURL, includingPropertiesForKeys: nil, options: [.skipsPackageDescendants, .skipsHiddenFiles]) else {
            log.error("Failed to create file enumerator at \(rootPath, privacy: .public)")
            return
        }

        var files: [String] = []

        while let url = enumerator.nextObject() as? URL {
            let path = url.path

            if enumerator.level > 2 { enumerator.skipDescendants() }

            /// Special handling for HLS downloads, which are a movpkg bundle.
            /// `.skipsPackageDescendants` should take care of this, but just in case...
            guard !url.deletingLastPathComponent().lastPathComponent.hasSuffix("movpkg") else { continue }

            /// In order to match a downloaded file with the corresponding asset, we only care about the last two path components,
            /// which will compose to something like `2023/wwdc2023-10042_hd.mp4`. The URL above has the full path, this takes care of it.
            let relativePath = url.pathComponents.suffix(2).joined(separator: "/")

            files.append(relativePath)
        }

        guard !files.isEmpty else { return }

        log.info("Found \(files.count, privacy: .public) downloaded files")

        storage.updateDownloadedFlag(true, forAssetsAtPaths: files)

        files.forEach { NotificationCenter.default.post(name: .DownloadManagerFileAddedNotification, object: $0) }

        if existingVideoFiles.count == 0 {
            existingVideoFiles = files
            return
        }

        let removedFiles = existingVideoFiles.filter { !files.contains($0) }

        if !removedFiles.isEmpty {
            log.info("Found \(removedFiles.count, privacy: .public) removed downloads")

            storage.updateDownloadedFlag(false, forAssetsAtPaths: removedFiles)

            removedFiles.forEach { NotificationCenter.default.post(name: .DownloadManagerFileDeletedNotification, object: $0) }
        }

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
