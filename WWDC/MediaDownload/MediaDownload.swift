import Cocoa
import Combine

@frozen
public enum MediaDownloadState: Codable, Hashable {
    case waiting
    case downloading(progress: Double)
    case paused(progress: Double)
    case failed(message: String)
    case completed
    case cancelled
}

/// Represents a media download, encapsulating its state.
public final class MediaDownload: Identifiable, ObservableObject, Hashable, Codable {
    /// Internal representation used for Codable conformance.
    fileprivate struct Storage: Codable {
        var id: String
        var relativeLocalPath: String
        var creationDate: Date
        var title: String
        var remoteURL: URL
        var temporaryLocalFileURL: URL?
        var state: MediaDownloadState
    }

    public struct ProgressStats: Hashable {
        fileprivate static let minElapsedProgressForETA: Double = 0.01
        fileprivate static let ppsObservationsLimit = 500
        private var elapsedTime: Double = 0
        private var ppsObservations: [Double] = []
        private var pps: Double = -1
        private var lastProgressDate = Date()
        private var ppsAverage: Double {
            guard !ppsObservations.isEmpty else { return -1 }
            return ppsObservations.reduce(Double(0), +) / Double(ppsObservations.count)
        }
        fileprivate var progress: Double = -1

        public var eta: Double? {
            didSet {
                formattedETA = eta.flatMap { Self.formattedETA(from: $0) }
            }
        }

        public var formattedETA: String?

        init() { }
    }

    /// When the download is in progress, reports statistics about the download (such as the estimated time for completion).
    @Published public private(set) var stats: ProgressStats?

    private var storage: Storage

    /// The unique identifier for the content being downloaded.
    public private(set) var id: String {
        get { storage.id }
        set { storage.id = newValue }
    }

    /// Local path to where the file will be saved after downloading, relative to the downloads directory.
    public private(set) var relativeLocalPath: String {
        get { storage.relativeLocalPath }
        set { storage.relativeLocalPath = newValue }
    }

    /// Date when this download was first created.
    public private(set) var creationDate: Date {
        get { storage.creationDate }
        set { storage.creationDate = newValue }
    }

    /// User-facing title representing the content.
    public private(set) var title: String {
        get { storage.title }
        set { storage.title = newValue }
    }

    /// URL to the remote content being downloaded.
    public private(set) var remoteURL: URL {
        get { storage.remoteURL }
        set { storage.remoteURL = newValue }
    }

    /// URL to the temporary location where the system will download the media into.
    /// After the download completes, the file is moved into its final location.
    public internal(set) var temporaryLocalFileURL: URL? {
        get { storage.temporaryLocalFileURL }
        set { storage.temporaryLocalFileURL = newValue }
    }

    /// Observers of the download's state may use this so that subscriptions
    /// die automatically when the `MediaDownload` object is discarded.
    var cancellables = Set<AnyCancellable>()

    /// The current state of the download.
    @Published public internal(set) var state: MediaDownloadState {
        didSet {
            storage.state = state
            updateStatsIfNeeded()
        }
    }

    init(id: String, title: String, remoteURL: URL, relativeLocalPath: String, state: MediaDownloadState = .waiting, creationDate: Date = .now) {
        self.storage = Storage(id: id, relativeLocalPath: relativeLocalPath, creationDate: creationDate, title: title, remoteURL: remoteURL, temporaryLocalFileURL: nil, state: state)
        self.state = state
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public static func == (lhs: MediaDownload, rhs: MediaDownload) -> Bool { lhs.id == rhs.id }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.storage = try container.decode(Storage.self)
        self.state = storage.state
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(storage)
    }
}

public extension MediaDownloadState {
    var isFinal: Bool {
        switch self {
        case .failed, .completed, .cancelled:
            return true
        default:
            return false
        }
    }

    var isResumable: Bool {
        switch self {
        case .paused, .failed, .cancelled:
            return true
        default:
            return false
        }
    }

    var isCompleted: Bool { self == .completed }

    var isPaused: Bool {
        guard case .paused = self else { return false }
        return true
    }

    var isFailed: Bool {
        guard case .failed = self else { return false }
        return true
    }

    var isCancelled: Bool { self == .cancelled }

    var progress: Double? {
        switch self {
        case .downloading(let progress), .paused(let progress): return progress
        default: return nil
        }
    }

    /// Convenience for transitioning into paused state with current progress (if any).
    func paused() -> Self {
        switch self {
        case .downloading(let progress), .paused(let progress):
            return .paused(progress: progress)
        default:
            return .paused(progress: 0)
        }
    }
}

public extension MediaDownload {
    var isResumable: Bool { state.isResumable }
    var isPaused: Bool { state.isPaused }
    var isFailed: Bool { state.isFailed }
    var isCompleted: Bool { state.isCompleted }
    var isCancelled: Bool { state.isCancelled }
    var progress: Double? { state.progress }

    /// Whether the download can be manually removed from the list by the user.
    var isRemovable: Bool { isCompleted || isCancelled || isFailed }
    /// Whether the user can request that the download be attempted again.
    var isRetryable: Bool { isCancelled || isFailed }
}

// MARK: - ETA Support

private extension MediaDownload {
    func updateStatsIfNeeded() {
        guard case .downloading(let progress) = state else { return }

        var stats = self.stats ?? ProgressStats()
        stats.update(with: progress)
        self.stats = stats
    }
}

private extension MediaDownload.ProgressStats {
    mutating func update(with progress: Double) {
        let interval = Date().timeIntervalSince(lastProgressDate)
        lastProgressDate = Date()

        let currentPPS = progress / elapsedTime

        if currentPPS.isFinite && !currentPPS.isZero && !currentPPS.isNaN {
            ppsObservations.append(currentPPS)
            if ppsObservations.count >= Self.ppsObservationsLimit {
                ppsObservations.removeFirst()
            }
        }

        elapsedTime += interval

        if self.progress > Self.minElapsedProgressForETA {
            if pps < 0 {
                pps = progress / elapsedTime
            }

            eta = (1/ppsAverage) - elapsedTime
        }

        self.progress = progress
    }

    static func formattedETA(from eta: Double) -> String {
        let time = Int(eta)

        let seconds = time % 60
        let minutes = (time / 60) % 60
        let hours = (time / 3600)

        if hours >= 1 {
            return String(format: "%0.2d:%0.2d:%0.2d", hours, minutes, seconds)
        } else {
            return String(format: "%0.2d:%0.2d", minutes, seconds)
        }
    }
}
