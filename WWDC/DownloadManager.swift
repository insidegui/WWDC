//
//  DownloadManager.swift
//  WWDC
//
//  Created by Guilherme Rambo on 06/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
import Combine
import ConfCore
import RealmSwift
import OSLog

enum DownloadStatus {
    case none
    case downloading(DownloadManager.DownloadInfo)
    case paused(DownloadManager.DownloadInfo)
    case cancelled
    case finished
    case failed(Error?)
}

final class DownloadManager: NSObject, Logging {

    // Changing this dynamically isn't supported. Delete all downloads when switching
    // from one quality to another otherwise you'll encounter minor unexpected behavior
    static let downloadQuality = SessionAssetType.hdVideo

    static let log = makeLogger()
    private let configuration = URLSessionConfiguration.background(withIdentifier: "WWDC Video Downloader")
    private var backgroundSession: Foundation.URLSession!
    private var downloadTasks: [String: Download] = [:] {
        didSet {
            downloads = Array(downloadTasks.values)
        }
    }
    @Published private(set) var downloads: [Download] = []
    private let defaults = UserDefaults.standard

    var storage: Storage!

    static let shared: DownloadManager = DownloadManager()

    override init() {
        super.init()

        // TODO: Check a little harder into whether we can keep the delegate methods off the main thread.
        // TODO: There are actually UI perf concerns when doing a lot of downloads
        backgroundSession = URLSession(configuration: configuration, delegate: self, delegateQueue: .main)
    }

    // MARK: - Session-based Public API

    func start(with storage: Storage) {
        self.storage = storage

        backgroundSession.getTasksWithCompletionHandler { _, _, pendingTasks in
            for task in pendingTasks {
                if let key = task.originalRequest?.url?.absoluteString,
                    let remoteURL = URL(string: key),
                    let asset = storage.asset(with: remoteURL),
                    let session = asset.session.first {

                    self.downloadTasks[key] = Download(session: SessionIdentifier(session.identifier), remoteURL: key, task: task)
                } else {
                    // We have a task that is not associated with a session at all, lets cancel it
                    task.cancel()
                }
            }
        }

        _ = NotificationCenter.default.addObserver(forName: .LocalVideoStoragePathPreferenceDidChange, object: nil, queue: nil) { _ in
            self.monitorDownloadsFolder()
        }

        updateDownloadedFlagsOfPreviouslyDownloaded()
        monitorDownloadsFolder()
    }

    func download(_ sessions: [Session], resumeIfPaused: Bool = true) {
        // This function is optimized so that many downloads can be started simultaneously and efficiently

        // Step 1: Collect all the remote URLs on the main thread for Realm reasons
        var sessionURLMap = [SessionIdentifier: String]()
        for session in sessions {
            guard let asset = session.asset(ofType: DownloadManager.downloadQuality) else { continue }

            let url = asset.remoteURL

            if resumeIfPaused && isDownloading(url) {
                _ = resumeDownload(url)
                continue
            }

            if hasDownloadedVideo(asset: asset) {
                continue
            }

            sessionURLMap[SessionIdentifier(session.identifier)] = url
        }

        // Step 2. Move to the background and start the downloads
        DispatchQueue.global(qos: .background).async {
            var successfullyStartedTasks = [String: Download]()
            for (sessionID, urlString) in sessionURLMap {
                if let task = URL(string: urlString).map({ self.backgroundSession.downloadTask(with: $0) }),
                    let key = task.originalRequest?.url?.absoluteString {

                    successfullyStartedTasks[key] = Download(session: sessionID, remoteURL: key, task: task)
                } else {
                    NotificationCenter.default.post(name: .DownloadManagerDownloadFailed, object: urlString)
                }
            }

            // Step 3. Update the downloadTasks in 1 shot on the main thread
            // This prevents observers from being thrashed by adding tasks individually in a loop
            // which leads to application spins.
            DispatchQueue.main.async {
                self.downloadTasks.merge(successfullyStartedTasks, uniquingKeysWith: { a, b in b })

                for (url, download) in successfullyStartedTasks {
                    download.task?.resume()
                    NotificationCenter.default.post(name: .DownloadManagerDownloadStarted, object: url)
                }
            }
        }
    }

    func cancelDownloads(_ sessions: [Session]) {
        var urls = [String]()
        for session in sessions {
            guard let url = session.asset(ofType: DownloadManager.downloadQuality)?.remoteURL else { continue }
            urls.append(url)
        }

        return cancelDownloads(urls)
    }

    func isDownloading(_ session: Session) -> Bool {
        guard let url = session.asset(ofType: DownloadManager.downloadQuality)?.remoteURL else { return false }

        return isDownloading(url)
    }

    func isDownloadable(_ session: Session) -> Bool {
        return session.asset(ofType: DownloadManager.downloadQuality) != nil
    }

    func downloadedFileURL(for session: Session) -> URL? {
        guard let asset = session.asset(ofType: DownloadManager.downloadQuality) else { return nil }

        let path = localStoragePath(for: asset)

        guard FileManager.default.fileExists(atPath: path) else { return nil }

        return URL(fileURLWithPath: path)
    }

    func hasDownloadedVideo(session: Session) -> Bool {
        return downloadedFileURL(for: session) != nil
    }

    func hasDownloadedVideo(asset: SessionAsset) -> Bool {
        let path = localStoragePath(for: asset)

        return FileManager.default.fileExists(atPath: path)
    }

    func deleteDownloadedFile(for session: Session) {
        guard let asset = session.asset(ofType: DownloadManager.downloadQuality) else { return }

        do {
            try removeDownload(asset.remoteURL)
        } catch {
            WWDCAlert.show(with: error)
        }
    }

    func downloadStatusObservable(for download: Download) -> AnyPublisher<DownloadStatus, Never>? {
        guard let remoteURL = URL(string: download.remoteURL) else { return nil }
        guard let downloadingAsset = storage.asset(with: remoteURL) else { return nil }

        return downloadStatusObservable(for: downloadingAsset)
    }

    func downloadStatusObservable(for session: Session) -> AnyPublisher<DownloadStatus, Never>? {
        guard let asset = session.asset(ofType: DownloadManager.downloadQuality) else { return nil }

        return downloadStatusObservable(for: asset)
    }

    private func downloadStatusObservable(for asset: SessionAsset) -> AnyPublisher<DownloadStatus, Never>? {
        // TODO: This function could probably be improved. Too much duplication, also I don't know that capturing this state locally like this
        // TODO: is needed and it feels odd
        var latestInfo: DownloadInfo = .unknown

        let currentDownloadState: () -> DownloadStatus = {
            if let download = self.downloadTasks[asset.remoteURL],
               let task = download.task {
                latestInfo = DownloadInfo(task: task)

                switch task.state {
                case .running:
                    return .downloading(latestInfo)
                case .suspended:
                    return .paused(latestInfo)
                case .canceling:
                    return .cancelled
                case .completed:
                    return .finished
                @unknown default:
                    assertionFailure("An unexpected case was discovered on an non-frozen obj-c enum")
                    return .downloading(latestInfo)
                }
            } else if self.hasDownloadedVideo(remoteURL: asset.remoteURL) {
                return .finished
            } else {
                return .none
            }
        }

        let nc = NotificationCenter.default
        let fileDeleted = nc.publisher(for: .DownloadManagerFileDeletedNotification, filteredBy: asset.relativeLocalURL).map { _ in
            DownloadStatus.none
        }
        let fileAdded = nc.publisher(for: .DownloadManagerFileAddedNotification, filteredBy: asset.relativeLocalURL).map { _ in
            DownloadStatus.finished
        }

        let progress = nc.publisher(for: .DownloadManagerDownloadProgressChanged, filteredBy: asset.remoteURL).map { note in
            if let info = note.userInfo?["info"] as? DownloadInfo {
                latestInfo = info
                if info.taskState == .suspended {
                    // We can get progress updates that were from while the task was suspending
                    return DownloadStatus.paused(info)
                } else {
                    return DownloadStatus.downloading(info)
                }
            } else {
                return DownloadStatus.downloading(.unknown)
            }
        }

        let paused = nc.publisher(for: .DownloadManagerDownloadPaused, filteredBy: asset.remoteURL).map { _ in
            DownloadStatus.paused(latestInfo)
        }

        let resumed = nc.publisher(for: .DownloadManagerDownloadResumed, filteredBy: asset.remoteURL).map { _ in
            DownloadStatus.downloading(latestInfo)
        }

        let cancelled = nc.publisher(for: .DownloadManagerDownloadCancelled, filteredBy: asset.remoteURL).map { _ in
            DownloadStatus.cancelled
        }

        let finished = nc.publisher(for: .DownloadManagerDownloadFinished, filteredBy: asset.remoteURL).map { _ in
            DownloadStatus.finished
        }

        let failed = nc.publisher(for: .DownloadManagerDownloadFailed, filteredBy: asset.remoteURL).map { notification in
            let error = notification.userInfo?["error"] as? Error
            return DownloadStatus.failed(error)
        }

        return Just(currentDownloadState())
            .merge(with: fileDeleted)
            .merge(with: fileAdded)
            .merge(with: progress)
            .merge(with: paused)
            .merge(with: resumed)
            .merge(with: finished)
            .merge(with: cancelled)
            .merge(with: failed)
            .eraseToAnyPublisher()
    }

    // MARK: - URL-based Internal API

    fileprivate func localStoragePath(for asset: SessionAsset) -> String {
        return Preferences.shared.localVideoStorageURL.appendingPathComponent(asset.relativeLocalURL).path
    }

    private func pauseDownload(_ url: String) -> Bool {
        if let download = downloadTasks[url] {
            download.pause()
            return true
        }

        log.error("Unable to pause download of \(url, privacy: .public) because there's no task for that URL")

        return false
    }

    private func resumeDownload(_ url: String) -> Bool {
        if let download = downloadTasks[url], download.state == .suspended {
            download.resume()
            return true
        }

        log.error("Unable to resume download of \(url, privacy: .public) because there's no task for that URL")

        return false
    }

    private func cancelDownloads(_ urls: [String]) {
        for url in urls {
            if let download = downloadTasks[url] {
                download.task?.cancel()
                return
            }

            log.error("Unable to cancel download of \(url, privacy: .public) because there's no task for that URL")
        }
    }

    private func isDownloading(_ url: String) -> Bool {
        return downloadTasks[url] != nil
    }

    /// Given a remote URL, determines the asset that references the remote URL
    /// and returns a local URL, as a string, where the file can be downloaded
    /// to or where you'd expect to find it if it has already been downloaded
    private func lookupAssetLocalVideoPath(remoteURL: String) -> String? {
        guard let url = URL(string: remoteURL) else { return nil }

        guard let asset = storage.asset(with: url) else {
            return nil
        }

        let path = localStoragePath(for: asset)

        return path
    }

    private func hasDownloadedVideo(remoteURL url: String) -> Bool {
        guard let path = lookupAssetLocalVideoPath(remoteURL: url) else { return false }

        return FileManager.default.fileExists(atPath: path)
    }

    enum RemoveDownloadError: Error {
        case notDownloaded
        case fileSystem(Error)
        case internalError(String)
    }

    private func removeDownload(_ url: String) throws {
        if isDownloading(url) {
            cancelDownloads([url])
            return
        }

        if hasDownloadedVideo(remoteURL: url) {
            guard let path = lookupAssetLocalVideoPath(remoteURL: url) else {
                throw RemoveDownloadError.internalError("Unable to generate local video path from remote URL")
            }

            do {
                try FileManager.default.removeItem(atPath: path)
            } catch {
                throw RemoveDownloadError.fileSystem(error)
            }
        } else {
            throw RemoveDownloadError.notDownloaded
        }
    }

    // MARK: - File observation

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
        let expectedOnDisk = storage.sessions.filter(NSPredicate(format: "isDownloaded == true"))
        var notPresent = [String]()

        for session in expectedOnDisk {
            if let asset = session.asset(ofType: DownloadManager.downloadQuality) {
                if !hasDownloadedVideo(asset: asset) {
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
        guard let enumerator = FileManager.default.enumerator(atPath: path) else { return }

        var files: [String] = []

        while let path = enumerator.nextObject() as? String {
            if enumerator.level > 2 { enumerator.skipDescendants() }
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

extension DownloadManager: URLSessionDownloadDelegate, URLSessionTaskDelegate {

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let originalURL = downloadTask.originalRequest?.url else { return }

        let originalAbsoluteURLString = originalURL.absoluteString

        guard let localPath = lookupAssetLocalVideoPath(remoteURL: originalAbsoluteURLString) else { return }
        let destinationUrl = URL(fileURLWithPath: localPath)
        let destinationDir = destinationUrl.deletingLastPathComponent()

        do {
            if !FileManager.default.fileExists(atPath: destinationDir.path) {
                try FileManager.default.createDirectory(at: destinationDir, withIntermediateDirectories: true, attributes: nil)
            }

            try FileManager.default.moveItem(at: location, to: destinationUrl)

            downloadTasks.removeValue(forKey: originalAbsoluteURLString)

            NotificationCenter.default.post(name: .DownloadManagerDownloadFinished, object: originalAbsoluteURLString)
        } catch {
            NotificationCenter.default.post(name: .DownloadManagerDownloadFailed, object: originalAbsoluteURLString, userInfo: ["error": error])
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let originalURL = task.originalRequest?.url else { return }

        let originalAbsoluteURLString = originalURL.absoluteString

        downloadTasks.removeValue(forKey: originalAbsoluteURLString)

        if let error = error {
            switch error {
            case let error as URLError where error.code == URLError.cancelled:
                NotificationCenter.default.post(name: .DownloadManagerDownloadCancelled, object: originalAbsoluteURLString)
            default:
                NotificationCenter.default.post(name: .DownloadManagerDownloadFailed, object: originalAbsoluteURLString, userInfo: ["error": error])
            }
        }
    }

    struct DownloadInfo {
        let totalBytesWritten: Int64
        let totalBytesExpectedToWrite: Int64
        let progress: Double
        let taskState: URLSessionDownloadTask.State?

        init(task: URLSessionTask) {
            totalBytesExpectedToWrite = task.countOfBytesExpectedToReceive
            totalBytesWritten = task.countOfBytesReceived
            progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            taskState = task.state
        }

        init(totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64, progress: Double) {
            self.totalBytesWritten = totalBytesWritten
            self.totalBytesExpectedToWrite = totalBytesExpectedToWrite
            self.progress = progress
            self.taskState = nil
        }

        static let unknown = DownloadInfo(totalBytesWritten: 0, totalBytesExpectedToWrite: 0, progress: -1)
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard let originalURL = downloadTask.originalRequest?.url?.absoluteString else { return }

        let info = DownloadInfo(task: downloadTask)
        NotificationCenter.default.post(name: .DownloadManagerDownloadProgressChanged, object: originalURL, userInfo: ["info": info])
    }
}

extension DownloadManager {

    struct Download: Equatable {
        // Equatable can't be synthesized with a `weak` property for some reason
        static func == (lhs: DownloadManager.Download, rhs: DownloadManager.Download) -> Bool {
            return lhs.session == rhs.session && lhs.remoteURL == rhs.remoteURL && lhs.task == rhs.task
        }

        let session: SessionIdentifier
        fileprivate var remoteURL: String
        fileprivate weak var task: URLSessionDownloadTask?

        func pause() {
            guard let task = task else { return }
            task.suspend()
            NotificationCenter.default.post(name: .DownloadManagerDownloadPaused, object: remoteURL)
        }

        func resume() {
            guard let task = task else { return }
            task.resume()
            NotificationCenter.default.post(name: .DownloadManagerDownloadResumed, object: remoteURL)
        }

        func cancel() {
            guard let task = task else { return }
            task.cancel()
        }

        var state: URLSessionTask.State {
            return task?.state ?? .canceling
        }

        // swiftlint:disable:next cyclomatic_complexity
        static func sortingFunction(lhs: Download, rhs: Download) -> Bool {
            guard let left = lhs.task, let right = rhs.task else { return false }

            switch ((left.countOfBytesExpectedToReceive, left.state), (right.countOfBytesExpectedToReceive, right.state)) {
            // 1. known and running
            case ((1..., .running), (1..., .running)):
                break
            case ((1..., .running), _):
                return true
            case (_, (1..., .running)):
                return false

            // 2. known and suspended are next
            case ((1..., .suspended), (1..., .suspended)):
                break
            case ((1..., .suspended), _):
                return true
            case (_, (1..., .suspended)):
                return false

            // 3. Unknown & suspended
            case ((0, .suspended), (0, .suspended)):
                break
            case ((0, .suspended), _):
                return true
            case (_, (0, .suspended)):
                return false

            // 4. Unknown and running moving down
            case ((0, .running), (0, .running)):
                break
            case ((0, .running), _):
                return false
            case (_, (0, .running)):
                return true
            default:
                break
            }

            // Each "section" is sorted by identifier
            return right.taskIdentifier < left.taskIdentifier
        }
    }
}

private extension NotificationCenter {

    func publisher<T: Equatable>(for name: NSNotification.Name, filteredBy object: T) -> some Combine.Publisher<Notification, Never> {
        publisher(for: name, object: nil)
            .filter { notification in
                object == notification.object as? T
            }
    }
}
