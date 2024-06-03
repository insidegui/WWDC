import Foundation

/// A fake downloader that can be used for unit/UI testing.
public final class SimulatedMediaDownloadEngine: MediaDownloadEngine {

    /// If a `MediaDownload` started through the fake downloader has this identifier, then it will fail instead of succeed.
    public static let simulateFailureMediaDownloadID = "FAILTHIS"

    public var supportedExtensions: Set<String> = []

    public func supports(_ download: MediaDownload) -> Bool { true }

    public var simulatedInFlightDownloads = [MediaDownload]()

    public var manager: MediaDownloadManager

    public init(manager: MediaDownloadManager) {
        self.manager = manager
    }

    public func createSimulatedPendingTask(with id: MediaDownload.ID, state: MediaDownloadState) {
        guard self.tasksByDownloadID[id] == nil else { return }
        let task = SimulatedDownloadTask(downloadID: id, delegate: self, initialState: state)
        self.tasksByDownloadID[id] = task
        task.resume()
    }

    public func pendingDownloadTasks() async -> [MediaDownloadTask] {
        if let simulatePendingTaskIDs = UserDefaults.standard.string(forKey: "SimulatedDownloadEnginePendingTaskIDs").flatMap({ $0.components(separatedBy: ",").map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) }) }) {
            for taskID in simulatePendingTaskIDs {
                createSimulatedPendingTask(with: taskID, state: .waiting)
            }
        }
        return Array(tasksByDownloadID.values)
    }

    public func fetchTask(for id: MediaDownload.ID) async -> MediaDownloadTask? {
        await pendingDownloadTasks().first(where: { (try? $0.mediaDownloadID()) == id })
    }

    private var tasksByDownloadID = [MediaDownload.ID: SimulatedDownloadTask]()

    private func task(for downloadID: MediaDownload.ID) throws -> SimulatedDownloadTask {
        guard let task = tasksByDownloadID[downloadID] else {
            throw "Couldn't find a task for \(downloadID)"
        }
        return task
    }

    public func start(_ download: MediaDownload) async throws {
        let task = tasksByDownloadID[download.id, default: SimulatedDownloadTask(downloadID: download.id, delegate: self)]
        task.resume()
    }

    public func resume(_ download: MediaDownload) throws {
        guard let task = tasksByDownloadID[download.id] else {
            throw "Download not found for \(download.id)."
        }
        
        assertSetState(.waiting, for: task)

        task.resume()
    }

    public func pause(_ download: MediaDownload) throws {
        try task(for: download.id).pause()
    }
    
    public func cancel(_ download: MediaDownload) throws {
        try task(for: download.id).cancel()
    }

    public func cancel(_ task: MediaDownloadTask) throws {
        guard let typedTask = task as? SimulatedDownloadTask else {
            throw "Invalid task: \(task)."
        }
        
        typedTask.cancel()

        if let taskKey = tasksByDownloadID.first(where: { $0.value === typedTask })?.key {
            tasksByDownloadID[taskKey] = nil
        }
    }

}

extension SimulatedMediaDownloadEngine: SimulatedDownloadTaskDelegate {
    func simulatedDownloadTaskResumed(_ task: SimulatedDownloadTask) {
        assertSetState(task.progress > 0 ? .downloading(progress: task.progress) : .waiting, for: task)
    }
    
    func simulatedDownloadTaskPaused(_ task: SimulatedDownloadTask) {
        assertSetState(.paused(progress: task.progress), for: task)
    }
    
    func simulatedDownloadTaskFailed(_ task: SimulatedDownloadTask, error: any Error) {
        assertSetState(.failed(message: String(describing: error)), for: task)
    }
    
    func simulatedDownloadTaskCancelled(_ task: SimulatedDownloadTask) {
        assertSetState(.cancelled, for: task)
    }
    
    func simulatedDownloadTaskProgressChanged(_ task: SimulatedDownloadTask, progress: Double) {
        assertSetState(.downloading(progress: progress), for: task)
    }
    
    func simulatedDownloadTaskCompleted(_ task: SimulatedDownloadTask, location: URL) {
        assertSetState(.completed, for: task, location: location)
    }
}

protocol SimulatedDownloadTaskDelegate: AnyObject {
    func simulatedDownloadTaskResumed(_ task: SimulatedDownloadTask)
    func simulatedDownloadTaskPaused(_ task: SimulatedDownloadTask)
    func simulatedDownloadTaskFailed(_ task: SimulatedDownloadTask, error: Error)
    func simulatedDownloadTaskCancelled(_ task: SimulatedDownloadTask)
    func simulatedDownloadTaskProgressChanged(_ task: SimulatedDownloadTask, progress: Double)
    func simulatedDownloadTaskCompleted(_ task: SimulatedDownloadTask, location: URL)
}

final class SimulatedDownloadTask: MediaDownloadTask {
    var downloadID: MediaDownload.ID
    weak var delegate: SimulatedDownloadTaskDelegate?
    private(set) var progress: Double = 0

    init(downloadID: MediaDownload.ID, delegate: SimulatedDownloadTaskDelegate, initialState: MediaDownloadState = .waiting) {
        self.downloadID = downloadID
        self.delegate = delegate
        self.internalState = initialState
    }

    func mediaDownloadID() throws -> MediaDownload.ID {
        downloadID
    }
    
    func setMediaDownloadID(_ id: MediaDownload.ID) {
        self.downloadID = id
    }

    @SimulatedTaskActor
    private var internalState = MediaDownloadState.waiting

    private var internalProgressTask: Task<Void, Never>?

    @SimulatedTaskActor
    private func updateInternalState(_ state: MediaDownloadState, location: URL? = nil) async {
        /// After reaching a final state, the download state can't be changed.
        guard !internalState.isFinal else {
            return
        }

        internalState = state

        await MainActor.run {
            switch state {
            case .waiting:
                break
            case .downloading(let progress):
                self.delegate?.simulatedDownloadTaskProgressChanged(self, progress: progress)
            case .paused:
                self.delegate?.simulatedDownloadTaskPaused(self)
            case .failed(let message):
                self.delegate?.simulatedDownloadTaskFailed(self, error: message)
            case .completed:
                guard let location else {
                    self.delegate?.simulatedDownloadTaskFailed(self, error: "Missing file location for completed task.")
                    return
                }
                self.delegate?.simulatedDownloadTaskCompleted(self, location: location)
            case .cancelled:
                self.delegate?.simulatedDownloadTaskCancelled(self)
            }
        }
    }

    func resume() {
        Task {
            try? await Task.sleep(nanoseconds: 200 * NSEC_PER_MSEC)

            await updateInternalState(.downloading(progress: self.progress))

            runProgressTask()
        }
    }

    func pause() {
        internalProgressTask?.cancel()
        internalProgressTask = nil

        Task {
            await updateInternalState(.paused(progress: progress))
        }
    }

    func cancel() {
        Task {
            await updateInternalState(.cancelled)
        }
    }

    private func runProgressTask() {
        internalProgressTask = Task {
            await progressTaskMain()
        }
    }

    private func progressTaskMain() async {
        do {
            while !(await internalState.isFinal) {
                await Task.yield()

                try Task.checkCancellation()

                try? await Task.sleep(nanoseconds: 100 * NSEC_PER_MSEC)

                let p = min(self.progress + 0.02, 1.0)

                self.progress = p

                await updateInternalState(.downloading(progress: p))

                try Task.checkCancellation()

                let state = await internalState

                guard state != .cancelled else { break }

                if p >= 0.2, self.downloadID == SimulatedMediaDownloadEngine.simulateFailureMediaDownloadID {
                    await updateInternalState(.failed(message: "Simulated error."))
                    break
                }

                if p >= 1 {
                    let simulatedFileURL = URL(fileURLWithPath: NSTemporaryDirectory())
                        .appendingPathComponent("SimulatedDownload-\(UUID()).tmp")

                    try Data("Simulated Download".utf8).write(to: simulatedFileURL)

                    await updateInternalState(.completed, location: simulatedFileURL)
                }
            }
        } catch is CancellationError {
            return
        } catch {
            await updateInternalState(.failed(message: error.localizedDescription))
        }
    }

}

@globalActor
private final actor SimulatedTaskActor: GlobalActor {
    static let shared = SimulatedTaskActor()
}
