import Cocoa

/// Describes a type of media content that can be downloaded.
public protocol DownloadableMediaVariant: Hashable { }

/// Protocol adopted by types that have media that can be downloaded by ``MediaDownloadManager``.
public protocol DownloadableMediaContainer: Identifiable where ID == String {
    /// The type that describes the supported downlodable media variants.
    associatedtype MediaVariant: DownloadableMediaVariant

    /// All supported media download variants ordered from most to least preferred.
    static var mediaDownloadVariants: [MediaVariant] { get }

    /// User-facing title for the content.
    var title: String { get }

    /// Returns the local path where the downloaded variant should be written to,
    /// relative to the root downloads directory.
    func relativeLocalPath(for variant: MediaVariant) -> String?

    /// Returns the remote URL for downloading media of the specified variant.
    func remoteDownloadURL(for variant: MediaVariant) -> URL?
}

/// Adopted by types that implement the underlying mechanism for downloading a given media variant.
public protocol MediaDownloadEngine: AnyObject {
    /// If the engine can check for support by file extension, return the set of supported extensions.
    /// The default implementation for ``supports(_:)`` uses this.
    var supportedExtensions: Set<String> { get }

    /// Whether this engine can be used to perform the specified download.
    func supports(_ download: MediaDownload) -> Bool

    /// Reference to the download manager responsible for this engine.
    /// Doesn't have to be weak because the objects involved are effectivelly singletons.
    var manager: MediaDownloadManager { get }

    /// Called by the download manager when activated.
    init(manager: MediaDownloadManager)

    /// Invoked when the download manager is activated in order to get
    /// the latest state of tasks that were active when the app was not running.
    func pendingDownloadTasks() async -> [MediaDownloadTask]

    /// Begins downloading.
    func start(_ download: MediaDownload) async throws

    /// Temporarily pauses the download.
    func pause(_ download: MediaDownload) throws

    /// Resume  a paused download.
    func resume(_ download: MediaDownload) throws

    /// Cancels the download.
    func cancel(_ download: MediaDownload) throws

    /// Cancels the task.
    /// Called by the manager when restoring a download fails in order
    /// to ensure that the task is purged.
    func cancel(_ task: MediaDownloadTask) throws

    /// Retrieves an existing task for the specified media ID.
    func fetchTask(for id: MediaDownload.ID) async -> MediaDownloadTask?
}

/// Protocol adopted by types that represent a task that performs a ``MediaDownload``.
/// There's an extension on `URLSessionTask` implementing all requirements.
public protocol MediaDownloadTask {
    func mediaDownloadID() throws -> MediaDownload.ID
    func setMediaDownloadID(_ id: MediaDownload.ID)
}

/// Protocol adopted by types that provide support for persisting ``MediaDownload`` objects.
/// An instance of such a type is used by ``MediaDownloadManager`` when restoring pending downloads between app launches.
public protocol MediaDownloadMetadataStorage: AnyObject {
    /// Fetches the list of identifiers that have been persisted in the store.
    func persistedIdentifiers() throws -> Set<MediaDownload.ID>

    /// Fetches an existing media download with the specified id.
    func fetch(_ id: MediaDownload.ID) throws -> MediaDownload
    
    /// Persists the download object.
    func persist(_ download: MediaDownload) throws

    /// Removes the download with the specified id from storage.
    func remove(_ id: MediaDownload.ID) throws
}

// MARK: - Default Implementations

public extension MediaDownloadEngine {
    /// Returns `true` if the ``MediaDownload/relativeLocalPath`` has an extension included in ``supportedExtensions``.
    func supports(_ download: MediaDownload) -> Bool {
        guard let fileExtension = download.relativeLocalPath.components(separatedBy: ".").last?.lowercased() else {
            assertionFailure("Attempting to check-in a download with a local path that doesn't have a file extension: \(download.relativeLocalPath)")
            return false
        }

        return supportedExtensions.contains(fileExtension)
    }
}

public extension DownloadableMediaContainer {
    func downloadEngineType(for variant: MediaVariant) -> MediaDownloadEngine.Type? { nil }
}
