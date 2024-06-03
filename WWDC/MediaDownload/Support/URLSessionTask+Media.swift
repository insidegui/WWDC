import Foundation

extension URLSessionTask: MediaDownloadTask {
    public func mediaDownloadID() throws -> MediaDownload.ID {
        guard let taskDescription else { throw "Media download task is missing a task description." }
        return taskDescription
    }
    
    public func setMediaDownloadID(_ id: MediaDownload.ID) {
        taskDescription = id
    }

    var debugDownloadID: String { taskDescription ?? "<unknown>" }
}
