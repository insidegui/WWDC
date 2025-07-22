import Cocoa
import OSLog
import ConfCore

public final class URLSessionMediaDownloadEngine: NSObject, MediaDownloadEngine, Logging {
    public static let log = makeLogger()

    public let supportedExtensions: Set<String> = ["mp4", "mov", "m4v"]

    public var manager: MediaDownloadManager

    public init(manager: MediaDownloadManager) {
        self.manager = manager
    }

    private lazy var configuration = URLSessionConfiguration.background(
        withIdentifier: Bundle.main.backgroundURLSessionIdentifier(suffix: "URLSessionMediaDownloadEngine")
    )

    private lazy var session = URLSession(configuration: configuration, delegate: self, delegateQueue: .main)

    /// Download ID to download task.
    private let tasks = NSCache<NSString, URLSessionTask>()

    public func pendingDownloadTasks() async -> [MediaDownloadTask] {
        let retrievedTasks = await session.allTasks

        let validTasks = retrievedTasks.filter { task in
            guard task.taskDescription != nil else {
                log.warning("Dropping task without description: \(task, privacy: .public)")
                return false
            }
            return true
        }
        let invalidTasks = retrievedTasks.filter { !validTasks.contains($0) }
        for task in invalidTasks {
            task.cancel()
        }

        for retrievedTask in validTasks {
            do {
                let id = try retrievedTask.mediaDownloadID()

                tasks.setObject(retrievedTask, forKey: id as NSString)
            } catch {
                log.fault("Download task is missing download ID: \(retrievedTask, privacy: .public)")
            }
        }

        return validTasks
    }

    public func fetchTask(for id: MediaDownload.ID) async -> MediaDownloadTask? {
        await session.allTasks.first(where: { $0.taskDescription == id })
    }

    private func existingTask(for downloadID: MediaDownload.ID) throws -> URLSessionTask {
        guard let task = tasks.object(forKey: downloadID as NSString) else {
            throw "Task not found for \(downloadID)"
        }
        return task
    }

    public func start(_ download: MediaDownload) async throws {
        let id = download.id
        
        log.debug("Start \(id, privacy: .public)")

        if let task = try? existingTask(for: id) {
            log.info("Found existing task for \(id, privacy: .public), resuming")
            task.resume()
            return
        }

        log.info("Creating new task for \(id, privacy: .public)")

        let request = URLRequest(url: download.remoteURL)
        let downloadTask = session.downloadTask(with: request)
        downloadTask.setMediaDownloadID(id)

        tasks.setObject(downloadTask, forKey: id as NSString)

        downloadTask.resume()
    }

    public func resume(_ download: MediaDownload) throws {
        let task = try existingTask(for: download.id)
        
        assertSetState(.waiting, for: task)

        task.resume()
    }

    /// Tasks that are currently in the process if being suspended.
    /// Used to ignore progress callbacks, avoiding race conditions.
    private var tasksBeingSuspended = Set<URLSessionTask>()

    public func pause(_ download: MediaDownload) throws {
        let task = try existingTask(for: download.id)

        tasksBeingSuspended.insert(task)

        task.suspend()

        assertSetState(download.state.paused(), for: task)

        DispatchQueue.main.async {
            self.tasksBeingSuspended.remove(task)
        }
    }
    
    public func cancel(_ download: MediaDownload) throws {
        try existingTask(for: download.id).cancel()
    }

    public func cancel(_ task: MediaDownloadTask) throws {
        guard let typedTask = task as? URLSessionTask else {
            throw "Invalid task type: \(task)."
        }

        guard let id = typedTask.taskDescription else {
            throw "Task is missing download ID: \(typedTask)."
        }

        tasks.removeObject(forKey: id as NSString)

        typedTask.cancel()
    }

}

extension URLSessionMediaDownloadEngine: URLSessionDownloadDelegate, URLSessionTaskDelegate {
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        let id = downloadTask.debugDownloadID

        log.info("Finished downloading for \(id, privacy: .public)")

        do {
            /// The temporary file provided by URLSession only exists until we return from this method, so move it into another place.
            let newTempLocation = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent(location.lastPathComponent)

            try FileManager.default.moveItem(at: location, to: newTempLocation)

            log.debug("Moved temporary download for \(id, privacy: .public) into \(newTempLocation.path)")

            assertSetState(.completed, for: downloadTask, location: newTempLocation)
        } catch {
            log.fault("Failed to move downloaded file for \(id, privacy: .public) into temporary location: \(error, privacy: .public)")
        }
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        let id = task.debugDownloadID

        defer {
            tasks.removeObject(forKey: id as NSString)
        }

        guard let error else {
            log.debug("Task completed: \(task)")
            return
        }

        if error.isURLSessionCancellation {
            log.warning("Task for \(id, privacy: .public) cancelled")

            /// We may get a cancellation callback after a task is cancelled due to restoration failing,
            /// in which case it'll be removed from our task cache before the callback occurs.
            /// When that's the case, we can ignore the callback.
            guard tasks.object(forKey: id as NSString) != nil else {
                log.warning("Ignoring cancellation callback for removed task \(id, privacy: .public)")
                return
            }

            assertSetState(.cancelled, for: task)
        } else {
            log.warning("Task for \(id, privacy: .public) completed with error: \(error, privacy: .public)")

            assertSetState(.failed(message: error.localizedDescription), for: task)
        }
    }

    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard !tasksBeingSuspended.contains(downloadTask) else {
            let id = downloadTask.debugDownloadID
            log.debug("Ignoring progress report for \(id, privacy: .public) because it's being suspended")
            return
        }

        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)

        assertSetState(.downloading(progress: progress), for: downloadTask)
    }
}

extension Error {
    var isURLSessionCancellation: Bool {
        let nsError = self as NSError
        return nsError.domain == NSURLErrorDomain && nsError.code == -999
    }
}
