import SwiftUI
import ConfCore
import RealmSwift

extension MediaDownloadManager {
    @MainActor
    func download(_ sessions: [Session]) {
        let containers = sessions.map(\.mediaContainer)
        performAction({ try await self.startDownload(for: $0) }, with: containers)
    }

    @MainActor
    func cancelDownload(for sessions: [Session]) {
        let containers = sessions.map(\.mediaContainer)
        performAction({ try self.cancelDownload(for: $0) }, with: containers)
    }

    @MainActor
    func pauseDownload(for sessions: [Session]) {
        let containers = sessions.map(\.mediaContainer)
        performAction({ try self.pauseDownload(for: $0) }, with: containers)
    }

    @MainActor
    func delete(_ sessions: [Session]) {
        let containers = sessions.map(\.mediaContainer)
        performAction({ try self.removeDownloadedMedia(for: $0) }, with: containers)
    }

    private func cancelDownload(for container: SessionMediaContainer) throws {
        guard let download = self.download(for: container) else {
            throw "Couldn't find download for \(container.id)."
        }
        try self.cancel(download)
    }

    private func pauseDownload(for container: SessionMediaContainer) throws {
        guard let download = self.download(for: container) else {
            throw "Couldn't find download for \(container.id)."
        }
        try self.pause(download)
    }

    private func performAction(_ action: @escaping (SessionMediaContainer) async throws -> Void, with sessions: [SessionMediaContainer]) {
        Task {
            var alerted = false
            for session in sessions {
                do {
                    try await action(session)
                } catch {
                    guard !alerted else { continue }
                    alerted = true

                    await NSAlert(error: error).runModal()
                }
            }
        }
    }
}
