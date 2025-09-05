import Cocoa
import AVFoundation
import OSLog
import ConfCore

public final class AVAssetMediaDownloadEngine: NSObject, MediaDownloadEngine, Logging {
    public static let log = makeLogger()

    public let supportedExtensions: Set<String> = ["movpkg"]

    public var manager: MediaDownloadManager

    public init(manager: MediaDownloadManager) {
        self.manager = manager
    }

    private lazy var configuration = URLSessionConfiguration.background(
        withIdentifier: Bundle.main.backgroundURLSessionIdentifier(suffix: "AVAssetMediaDownloadEngine")
    )

    private lazy var session = AVAssetDownloadURLSession(configuration: configuration, assetDownloadDelegate: self, delegateQueue: .main)

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

        let asset = AVURLAsset(url: download.remoteURL)

        let mediaSelection = try await asset.load(.preferredMediaSelection)

        guard let task = session.aggregateAssetDownloadTask(with: asset,
                                                            mediaSelections: [mediaSelection],
                                                            assetTitle: download.title,
                                                            assetArtworkData: nil,
                                                            options: [AVAssetDownloadTaskMinimumRequiredMediaBitrateKey: 265_000])
        else {
            throw "Failed to create aggregate download task for \(download.remoteURL)."
        }

        task.setMediaDownloadID(id)

        tasks.setObject(task, forKey: id as NSString)

        task.resume()
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
        guard let typedTask = task as? AVAggregateAssetDownloadTask else {
            throw "Invalid task type: \(task)."
        }

        guard let id = typedTask.taskDescription else {
            throw "Task is missing download ID: \(typedTask)."
        }

        tasks.removeObject(forKey: id as NSString)

        typedTask.cancel()
    }

}

extension AVAssetMediaDownloadEngine: AVAssetDownloadDelegate {

    private func handleTaskFinished(_ task: AVAssetDownloadTask, location: URL?) {
        let id = task.debugDownloadID

        log.info("Finished downloading for \(id, privacy: .public)")

        do {
            let newTempLocation: URL?

            if let location {
                /// The temporary file provided by URLSession only exists until we return from this method, so move it into another place.
                let tempURL = URL(fileURLWithPath: NSTemporaryDirectory())
                    .appendingPathComponent(location.lastPathComponent)

                try FileManager.default.moveItem(at: location, to: tempURL)

                log.debug("Moved temporary download for \(id, privacy: .public) into \(tempURL.path)")

                newTempLocation = tempURL
            } else {
                newTempLocation = nil
            }

            assertSetState(.completed, for: task, location: newTempLocation)
        } catch {
            log.fault("Failed to move downloaded file for \(id, privacy: .public) into temporary location: \(error, privacy: .public)")
        }
    }

    private func reportProgress(for task: MediaDownloadTask, totalTimeRangesLoaded loadedTimeRanges: [NSValue], timeRangeExpectedToLoad: CMTimeRange) {
        var percentComplete = 0.0
        for value in loadedTimeRanges {
            let loadedTimeRange: CMTimeRange = value.timeRangeValue
            percentComplete +=
                loadedTimeRange.duration.seconds / timeRangeExpectedToLoad.duration.seconds
        }

        assertSetState(.downloading(progress: percentComplete), for: task)
    }

    public func urlSession(_ session: URLSession, assetDownloadTask: AVAssetDownloadTask, didFinishDownloadingTo location: URL) {
        log.debug("\(#function)")

        handleTaskFinished(assetDownloadTask, location: location)
    }

    public func urlSession(_ session: URLSession, aggregateAssetDownloadTask: AVAggregateAssetDownloadTask, willDownloadTo location: URL) {
        log.debug("\(#function)")

        let id = aggregateAssetDownloadTask.debugDownloadID

        log.debug("Will download \(id, privacy: .public) to \(location.path)")

        assertSetState(for: aggregateAssetDownloadTask, location: location)
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?) {
        let id = task.debugDownloadID

        defer {
            tasks.removeObject(forKey: id as NSString)
        }

        guard let error else {
            log.debug("Task completed: \(task)")

            /// Location for this type of task is set by the `willDownloadTo` callback, so here we can just report completion.
            assertSetState(.completed, for: task)

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

    public func urlSession(_ session: URLSession, aggregateAssetDownloadTask: AVAggregateAssetDownloadTask, didCompleteFor mediaSelection: AVMediaSelection) {
        log.debug("\(#function)")

        /// This is super weird, but it's what Apple's sample code does :|
        aggregateAssetDownloadTask.resume()
    }

    public func urlSession(_ session: URLSession, assetDownloadTask: AVAssetDownloadTask, didLoad timeRange: CMTimeRange, totalTimeRangesLoaded loadedTimeRanges: [NSValue], timeRangeExpectedToLoad: CMTimeRange) {
        log.debug("\(#function)")

        reportProgress(for: assetDownloadTask, totalTimeRangesLoaded: loadedTimeRanges, timeRangeExpectedToLoad: timeRangeExpectedToLoad)
    }

    public func urlSession(_ session: URLSession, aggregateAssetDownloadTask: AVAggregateAssetDownloadTask, didLoad timeRange: CMTimeRange, totalTimeRangesLoaded loadedTimeRanges: [NSValue], timeRangeExpectedToLoad: CMTimeRange, for mediaSelection: AVMediaSelection) {
        guard !tasksBeingSuspended.contains(aggregateAssetDownloadTask) else {
            let id = aggregateAssetDownloadTask.debugDownloadID
            log.debug("Ignoring progress report for \(id, privacy: .public) because it's being suspended")
            return
        }

        reportProgress(for: aggregateAssetDownloadTask, totalTimeRangesLoaded: loadedTimeRanges, timeRangeExpectedToLoad: timeRangeExpectedToLoad)
    }
}
