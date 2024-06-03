import Cocoa
import AVFoundation
import OSLog
import Combine
import ConfCore

public final class MediaDownloadManager: ObservableObject, Logging {

    public static let log = makeLogger()

    public typealias Downloadable = DownloadableMediaContainer

    @MainActor
    @Published public private(set) var downloads = [MediaDownload]()

    /// Internal use only, propagates to published `downloads` property.
    private var mediaDownloads = Set<MediaDownload>() {
        didSet {
            DispatchQueue.main.async {
                self.downloads = self.mediaDownloads.sorted(by: { $0.creationDate < $1.creationDate })
            }
        }
    }

    /// Directory where downloaded content is stored.
    public var directoryURL: URL

    private let fileManager = FileManager()
    private let engineTypes: [MediaDownloadEngine.Type]
    private var engines = [MediaDownloadEngine]()
    private let metaStore: MediaDownloadMetadataStorage

    public init(directoryURL: URL,
         engines engineTypes: [MediaDownloadEngine.Type],
         metadataStorage metaStore: MediaDownloadMetadataStorage)
    {
        self.directoryURL = directoryURL
        self.engineTypes = engineTypes
        self.metaStore = metaStore
    }

    private var activated = false

    @MainActor
    public func activate() {
        guard !activated else { return }
        activated = true

        assert(!engineTypes.isEmpty, "\(String(describing: Self.self)) requires at least one engine")

        log.debug("Activating with \(self.engineTypes.count, privacy: .public) engine(s)")

        self.engines = engineTypes.map { $0.init(manager: self) }

        Task {
            await _restorePendingDownloads()
            await _purgeOrphanedDownloads()
        }
    }

    /// Starts downloading media for the specified content.
    /// Variants are in preferred order, the first variant that's available will be used.
    @discardableResult
    public func startDownload<T: Downloadable>(for content: T, variants: [T.MediaVariant] = T.mediaDownloadVariants) async throws -> MediaDownload {
        guard downloadedFileURL(for: content, variants: variants) == nil else {
            throw "Content has already been downloaded, remove existing download before attempting to download again."
        }

        do {
            for variant in variants {
                if let url = content.remoteDownloadURL(for: variant) {
                    guard let localPath = content.relativeLocalPath(for: variant) else {
                        throw "Unable to determine local path for downloading \(content.id), variant \(variant)."
                    }

                    return try await _startDownload(for: content, remoteURL: url, relativeLocalPath: localPath)
                }
            }

            throw "Couldn't find a downloadable variant for \(content.id)"
        } catch {
            log.error("Start failed for \(content.id, privacy: .public): \(error, privacy: .public)")
            
            throw error
        }
    }

    /// Fetch the existing local file URL for the specified content.
    /// - Parameters:
    ///   - content: The content to get the local file URL for.
    ///   - variants: Preferred variants, sorted by most to least preferred.
    /// - Returns: The existing local file URL for the first variant of the specified content.
    public func downloadedFileURL<T: Downloadable>(for content: T, variants: [T.MediaVariant] = T.mediaDownloadVariants) -> URL? {
        for variant in variants {
            guard let fileURL = _localFileURL(for: content, variant: variant) else { continue }
            if fileManager.fileExists(atPath: fileURL.path) { return fileURL }
        }
        return nil
    }
    
    /// Checks if a given content has been downloaded.
    /// - Parameters:
    ///   - content: The content to check.
    ///   - variants: Preferred variants, sorted by most to least preferred.
    /// - Returns: `true` if a local download exists for any of the specified variants.
    public func hasDownloadedMedia<T: Downloadable>(for content: T, variants: [T.MediaVariant] = T.mediaDownloadVariants) -> Bool {
        downloadedFileURL(for: content, variants: variants) != nil
    }

    /// Deletes existing downloaded media for the specified content / variants.
    public func removeDownloadedMedia<T: Downloadable>(for content: T, variants: [T.MediaVariant] = T.mediaDownloadVariants) throws {
        guard let fileURL = downloadedFileURL(for: content, variants: variants) else {
            throw "Download doesn't exist for \(content.id)."
        }
        try fileManager.removeItem(at: fileURL)
    }

    /// Returns the active download for the specified content, if any.
    public func download<T: Downloadable>(for content: T) -> MediaDownload? {
        try? _download(with: content.id)
    }

    /// Checks if there's an active download for the specified content.
    /// Returns `true` for any download state except for `.completed`.
    public func isDownloadingMedia<T: Downloadable>(for content: T) -> Bool {
        guard let download = (try? _download(with: content.id)) else { return false }
        return download.state != .completed
    }

    public func pause(_ download: MediaDownload) throws {
        let engine = try _engine(for: download)
        try engine.pause(download)
    }

    public func resume(_ download: MediaDownload) throws {
        let engine = try _engine(for: download)
        try engine.resume(download)
    }

    public func cancel(_ download: MediaDownload) throws {
        let engine = try _engine(for: download)
        try engine.cancel(download)

        try? _detach(download, persist: true, remove: true)
    }

    /// Removes all completed downloads from the list.
    public func clearCompleted() {
        let completedDownloads = mediaDownloads.filter(\.isCompleted)

        guard !completedDownloads.isEmpty else {
            log.info("Found no completed downloads to remove")
            return
        }

        log.info("Removing \(completedDownloads.count, privacy: .public) completed download(s) from the list")

        completedDownloads.forEach { mediaDownloads.remove($0) }
    }

    /// Removes the specified download from the list, if it's completed.
    public func clear(_ download: MediaDownload) {
        let id = download.id

        log.debug("Remove download \(id, privacy: .public)")

        guard mediaDownloads.contains(where: { $0.id == id }) else {
            log.warning("Couldn't find download \(id, privacy: .public)")
            return
        }

        guard download.isRemovable else {
            log.warning("Can't clear download that's not removable. State: \(download.state, privacy: .public)")
            return
        }

        mediaDownloads.remove(download)
    }

    /// Retries a failed download.
    public func retry(_ download: MediaDownload) async throws {
        guard download.isFailed else {
            throw "Can't retry a download that hasn't failed."
        }

        clear(download)

        try await _start(download: download, attach: true)
    }

}

// MARK: - API for MediaDownloading Implementations

/// APIs in this extension are meant to be used by implementations of ``MediaDownloading``.
extension MediaDownloadManager {
    /// Returns the download corresponding to the specified task.
    /// Meant to be called by implementations of ``MediaDownloading``.
    func _download(for task: MediaDownloadTask) throws -> MediaDownload {
        try _download(with: task.mediaDownloadID())
    }

    /// Returns the download corresponding to the specified download identifier.
    /// Meant to be called by implementations of ``MediaDownloading``.
    func _download(with id: MediaDownload.ID) throws -> MediaDownload {
        guard let download = self.mediaDownloads.first(where: { $0.id == id }) else {
            throw "Download not found for \(id)."
        }
        return download
    }

    /// Used internally to restore a pending download upon demand from a download engine lookup.
    /// The difference from the `_download(with:)` function above is that this will look up the download metadata
    /// from the meta store if needed and re-attach the download to the manager.
    /// This is needed because it's possible for an engine to request a download state update before we've finished the initial restoration process.
    func _onDemandRestoreDownload(with id: MediaDownload.ID) throws -> MediaDownload {
        /// Download is already available locally.
        if let download = mediaDownloads.first(where: { $0.id == id }) { return download }

        /// Check if we have stored metadata for the download.
        let restoredDownload = try metaStore.fetch(id)

        /// Attach and return the restored download.
        return try _attach(restoredDownload, persist: false)
    }

    func _persist(_ download: MediaDownload) {
        guard download.state != .completed else { return }

        let id = download.id

        do {
            try metaStore.persist(download)
        } catch {
            log.warning("Error persisting \(id, privacy: .public): \(error, privacy: .public)")
        }
    }
}

// MARK: MediaDownloadEngine Helpers

extension MediaDownloadEngine {
    /// Updates the state for the download associated with the given task.
    func updateState(_ state: MediaDownloadState? = nil, for task: MediaDownloadTask, temporaryLocalFileURL: URL? = nil) throws {
        let download = try manager._onDemandRestoreDownload(with: task.mediaDownloadID())

        let shouldPersist = download.shouldPersist(state) || temporaryLocalFileURL?.path != download.temporaryLocalFileURL?.path

        DispatchQueue.main.async {
            if let temporaryLocalFileURL { download.temporaryLocalFileURL = temporaryLocalFileURL }

            if let state { download.state = state }

            if shouldPersist { self.manager._persist(download) }
        }
    }

    func assertSetState(_ state: MediaDownloadState? = nil, for task: MediaDownloadTask, location: URL? = nil) {
        do {
            try updateState(state, for: task, temporaryLocalFileURL: location)
        } catch {
            let downloadID = (try? task.mediaDownloadID()) ?? "<unknown>"
            /// We may encounter a failure when updating to cancelled state, that can safely be ignored.
            if state?.isCancelled != true { assertionFailure("State update failed for \(downloadID): \(error)") }
        }
    }
}

// MARK: - Private API

private extension MediaDownloadManager {

    /// Returns the local file URL where the download should be stored, regardless of whether it exists.
    func _localFileURL<T: Downloadable>(for content: T, variant: T.MediaVariant) -> URL? {
        guard let relativePath = content.relativeLocalPath(for: variant) else { return nil }
        return directoryURL.appendingPathComponent(relativePath)
    }

    func _engine(for download: MediaDownload) throws -> MediaDownloadEngine {
        guard let supportedEngine = engines.first(where: { $0.supports(download) }) else {
            throw "Couldn't find a suitable engine for \(download.id) with relative local path \(download.relativeLocalPath)."
        }
        return supportedEngine
    }

    /// Creates and starts a download for the specified content and remote URL.
    func _startDownload<T: Downloadable>(for content: T, remoteURL: URL, relativeLocalPath: String) async throws -> MediaDownload {
        let id = content.id

        let download: MediaDownload
        var isNewDownload = false

        func createDownload() -> MediaDownload {
            isNewDownload = true

            return MediaDownload(
                id: content.id,
                title: content.title,
                remoteURL: remoteURL,
                relativeLocalPath: relativeLocalPath
            )
        }

        if let existingDownload = self.download(for: content) {
            log.info("Found existing download for \(id, privacy: .public) with state \(existingDownload.state, privacy: .public)")

            /// If we have an existing download, it must be in a resumable state and not completed.
            /// If completed, we start a new one, otherwise we just resume it.
            if existingDownload.isCompleted {
                try _detach(existingDownload, persist: false, remove: true)

                download = createDownload()
            } else {
                guard existingDownload.state.isResumable else {
                    throw "A download already exists for \(content.id)."
                }

                download = existingDownload
            }
        } else {
            log.info("Creating new download for \(id, privacy: .public)")

            download = createDownload()
        }

        return try await _start(download: download, attach: isNewDownload)
    }

    @discardableResult
    func _start(download: MediaDownload, attach: Bool) async throws -> MediaDownload {
        let engine = try _engine(for: download)

        if attach {
            try _attach(download, persist: true)
        }

        try await engine.start(download)

        return download
    }

}

// MARK: - In-Flight Download Management

private extension MediaDownloadManager {

    func _restorePendingDownloads() async {
        for engine in engines {
            await _restorePendingTasks(for: engine)
        }
    }

    func _restorePendingTasks<E: MediaDownloadEngine>(for engine: E) async {
        let pendingTasks = await engine.pendingDownloadTasks()

        guard !pendingTasks.isEmpty else { return }

        let name = String(describing: E.self)

        log.info("Restoring \(pendingTasks.count, privacy: .public) pending task(s) for \(name, privacy: .public)")

        for pendingTask in pendingTasks {
            do {
                let downloadID = try pendingTask.mediaDownloadID()

                let download = try metaStore.fetch(downloadID)

                try _attach(download, persist: false)

                log.info("Restored pending task \(downloadID, privacy: .public) on \(name, privacy: .public)")
            } catch {
                log.error("Error restoring pending download on \(name, privacy: .public): \(error, privacy: .public)")

                do {
                    try engine.cancel(pendingTask)
                } catch {
                    log.error("Error cancelling failed restore task on \(name, privacy: .public): \(error, privacy: .public)")
                }
            }
        }
    }

    /// Removes persisted metadata for any downloads that don't have a corresponding download engine task.
    func _purgeOrphanedDownloads() async {
        do {
            let persistedIdentifiers = try metaStore.persistedIdentifiers()

            for persistedIdentifier in persistedIdentifiers {
                /// If we have a download state for the download ID, then we don't need to continue any further.
                guard !self.mediaDownloads.contains(where: { $0.id == persistedIdentifier }) else { continue }

                /// If we don't have a download state, check each engine to see if we have a corresponding task,
                /// in which case it's possible that this download is still valid but hasn't been attached to yet.
                for engine in self.engines {
                    if await engine.fetchTask(for: persistedIdentifier) != nil { continue }
                }

                log.warning("Purging orphaned download: \(persistedIdentifier, privacy: .public)")

                do {
                    try metaStore.remove(persistedIdentifier)
                } catch {
                    log.error("Error purging orphaned download \(persistedIdentifier, privacy: .public): \(error, privacy: .public)")
                }
            }
        } catch {
            log.error("Failed to retrieve persisted download metadata: \(error, privacy: .public)")
        }
    }

    /// Starts monitoring the specified download, optionally persisting its metadata to the meta store.
    @discardableResult
    func _attach(_ download: MediaDownload, persist: Bool) throws -> MediaDownload {
        let id = download.id

        log.info("Attach \(id, privacy: .public) (persist? \(persist, privacy: .public))")

        guard !mediaDownloads.contains(download) else {
            if persist {
                throw "Attach requested for download that's already being tracked: \(id)"
            } else {
                return download
            }
        }

        if persist {
            try metaStore.persist(download)
        }

        mediaDownloads.insert(download)

        download.$state.removeDuplicates().sink { [weak self] state in
            guard let self else { return }
            self._stateChanged(for: id, with: state)
        }
        .store(in: &download.cancellables)

        return download
    }

    /// Stops monitoring the download.
    /// - Parameters:
    ///   - download: The download to stop monitoring.
    ///   - persist: Whether the download should be removed from the metadata store.
    ///   - remove: Whether the download should be removed from the user-facing list of downloads.
    func _detach(_ download: MediaDownload, persist: Bool, remove: Bool = false) throws {
        let id = download.id

        log.info("Detach \(id, privacy: .public) (persist? \(persist, privacy: .public))")

        guard mediaDownloads.contains(download) else {
            throw "Detach requested for download that's not being tracked: \(id)"
        }

        download.cancellables.removeAll()

        if persist {
            try metaStore.remove(id)
        }

        if remove {
            mediaDownloads.remove(download)
        }
    }

    func _stateChanged(for id: MediaDownload.ID, with state: MediaDownloadState) {
        log.info("📣 State changed for \(id, privacy: .public): \(state, privacy: .public)")

        self._performDetachIfNeeded(for: id, state: state)
    }

    /// Detaches the download if its completed or cancelled.
    func _performDetachIfNeeded(for id: MediaDownload.ID, state: MediaDownloadState) {
        guard state == .completed || state == .cancelled else { return }

        do {
            let download = try _download(with: id)

            /// Move completed download file into place, failing the download if this process fails.
            do {
                try _moveIntoPlaceIfNeeded(download, state: state)
            } catch {
                log.error("Moving into place failed for \(id, privacy: .public): \(error, privacy: .public)")
                
                DispatchQueue.main.async {
                    download.state = .failed(message: error.localizedDescription)
                }
                return
            }

            try _detach(download, persist: true)
        } catch {
            let detachReason = (state == .completed) ? "completed" : "cancelled"
            let message = "Error detaching \(detachReason) download \(id): \(error)"
            log.fault("\(message, privacy: .public)")
            assertionFailure(message)
        }
    }

    func _moveIntoPlaceIfNeeded(_ download: MediaDownload, state: MediaDownloadState) throws {
        let id = download.id

        #if DEBUG
        log.debug("\(#function, privacy: .public) called for \(id, privacy: .public) with state \(state, privacy: .public)")
        #endif

        guard state == .completed else { return }

        guard let temporaryLocalFileURL = download.temporaryLocalFileURL else {
            throw "Download for \(id) completed without a local file being available."
        }

        let destinationURL = directoryURL.appendingPathComponent(download.relativeLocalPath)

        let destinationFolderURL = destinationURL.deletingLastPathComponent()

        try destinationFolderURL.createIfNeeded()

        try fileManager.moveItem(at: temporaryLocalFileURL, to: destinationURL)

        log.debug("Successfully moved \(id, privacy: .public) into \(destinationURL.path)")
    }

}

extension MediaDownloadState: CustomStringConvertible {
    public var description: String {
        switch self {
        case .waiting:
            return "⌛️ Waiting"
        case .downloading(let progress):
            return "🛞 Downloading (\(Int(progress * 100))%)"
        case .paused:
            return "✋ Paused"
        case .failed(let message):
            return "💔 Failed: \(message)"
        case .completed:
            return "✅ Completed"
        case .cancelled:
            return "🥺 Cancelled"
        }
    }
}

private extension MediaDownload {
    func shouldPersist(_ newState: MediaDownloadState?) -> Bool {
        guard let newState, newState != state else { return false }

        /// Require a certain amount of progress change for persistence.
        if case .downloading(let newProgress) = newState, case .downloading(let currentProgress) = self.state {
            return abs(newProgress - currentProgress) >= 0.1
        } else {
            return true
        }
    }
}
