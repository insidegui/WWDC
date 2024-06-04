#if DEBUG
import Foundation

extension URL {
    static let testMP41 = URL(string: "https://devstreaming-cdn.apple.com/videos/wwdc/2022/10003/5/C8AAE478-A435-4DA4-8256-F32941E32204/downloads/wwdc2022-10003_hd.mp4")!
    static let testMP42 = URL(string: "https://devstreaming-cdn.apple.com/videos/wwdc/2022/110360/3/95EF8495-F291-49FD-8958-276AC76C222D/downloads/wwdc2022-110360_hd.mp4")!
}

public struct PreviewMediaContainer: DownloadableMediaContainer {
    public var downloadIdentifier: String { id }
    
    public static let mediaDownloadVariants = [MediaVariant.preview]

    public enum MediaVariant: String, DownloadableMediaVariant {
        case preview
    }

    public var title: String
    public var id: String
    public var remoteURL: URL

    public func relativeLocalPath(for variant: MediaVariant) -> String? { remoteURL.lastPathComponent }

    public func remoteDownloadURL(for variant: MediaVariant) -> URL? { remoteURL }

    public init(title: String, id: String, remoteURL: URL) {
        self.title = title
        self.id = id
        self.remoteURL = remoteURL
    }
}

public extension PreviewMediaContainer {
    static let preview1 = PreviewMediaContainer(title: "Preview Download 1", id: "preview-1", remoteURL: .testMP41)
    static let preview2 = PreviewMediaContainer(title: "Preview Download 2", id: "preview-2", remoteURL: .testMP42)

    static var previewContainers: [PreviewMediaContainer] { [.preview1, .preview2] }
}

public extension MediaDownload {
    static var preview1: MediaDownload {
        MediaDownload(
            id: PreviewMediaContainer.preview1.id,
            title: PreviewMediaContainer.preview1.title,
            remoteURL: PreviewMediaContainer.preview1.remoteURL,
            relativeLocalPath: PreviewMediaContainer.preview1.relativeLocalPath(for: .preview)!
        )
    }

    static var preview2: MediaDownload {
        MediaDownload(
            id: PreviewMediaContainer.preview2.id,
            title: PreviewMediaContainer.preview2.title,
            remoteURL: PreviewMediaContainer.preview2.remoteURL,
            relativeLocalPath: PreviewMediaContainer.preview2.relativeLocalPath(for: .preview)!
        )
    }
}

public extension MediaDownloadManager {
    static let preview: MediaDownloadManager = {
        let manager = MediaDownloadManager(
            directoryURL: URL(fileURLWithPath: NSTemporaryDirectory()),
            engines: [SimulatedMediaDownloadEngine.self],
            metadataStorage: EphemeralMediaDownloadMetadataStore()
        )

        Task {
            await manager.activate()

            do {
                for container in PreviewMediaContainer.previewContainers {
                    try? manager.removeDownloadedMedia(for: container)
                    
                    try await manager.startDownload(for: container)
                }
            } catch {
                preconditionFailure("Preview download manager failed to start simulated downloads: \(error)")
            }
        }

        return manager
    }()
}

public final class EphemeralMediaDownloadMetadataStore: MediaDownloadMetadataStorage {
    private let cache = NSCache<NSString, MediaDownload>()

    public func persistedIdentifiers() throws -> Set<MediaDownload.ID> { [] }

    public func fetch(_ id: MediaDownload.ID) throws -> MediaDownload {
        guard let obj = cache.object(forKey: id as NSString) else {
            throw "Metadata not found for \(id)"
        }
        return obj
    }

    public func persist(_ download: MediaDownload) throws {
        cache.setObject(download, forKey: download.id as NSString)
    }

    public func remove(_ id: MediaDownload.ID) throws {
        cache.removeObject(forKey: id as NSString)
    }
}
#endif
