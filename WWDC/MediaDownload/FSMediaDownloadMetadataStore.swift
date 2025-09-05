import Cocoa
import OSLog
import ConfCore

public final class FSMediaDownloadMetadataStore: MediaDownloadMetadataStorage, Logging {
    public static let log = makeLogger()

    public let directoryURL: URL
    private let fileManager = FileManager()
    private let cache = NSCache<NSString, MediaDownload>()

    public init(directoryURL: URL) {
        self.directoryURL = directoryURL
    }

    public func persistedIdentifiers() throws -> Set<MediaDownload.ID> {
        guard directoryURL.exists else { return [] }
        
        let contents = try fileManager.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants, .skipsPackageDescendants])
        
        return Set(
            contents
                .filter { $0.pathExtension == "plist" }
                .map { $0.deletingPathExtension().lastPathComponent }
        )
    }

    public func fetch(_ id: MediaDownload.ID) throws -> MediaDownload {
        if let cached = cache.object(forKey: id as NSString) {
            return cached
        }

        do {
            let url = try fileURL(for: id)

            guard url.exists else { throw "Metadata not found for \(id)." }

            let data = try Data(contentsOf: url)

            let download = try PropertyListDecoder.metaStore.decode(MediaDownload.self, from: data)

            cache.setObject(download, forKey: id as NSString)

            return download
        } catch {
            log.error("Error fetching \(id, privacy: .public): \(error, privacy: .public)")
            throw error
        }
    }
    
    public func persist(_ download: MediaDownload) throws {
        let id = download.id

        cache.setObject(download, forKey: id as NSString)

        do {
            let data = try PropertyListEncoder.metaStore.encode(download)

            let url = try fileURL(for: id)

            try data.write(to: url, options: .atomic)
        } catch {
            log.error("Error persisting \(id, privacy: .public): \(error, privacy: .public)")
            throw error
        }
    }
    
    public func remove(_ id: MediaDownload.ID) throws {
        cache.removeObject(forKey: id as NSString)

        guard directoryURL.exists else {
            log.fault("Asked to remove download \(id, privacy: .public), but metadata directory doesn't exist at \(self.directoryURL.path, privacy: .public)")
            return
        }

        do {
            try fileManager.removeItem(at: fileURL(for: id))
        } catch {
            log.error("Error deleting metadata for \(id, privacy: .public): \(error, privacy: .public)")
            throw error
        }
    }
}

private extension FSMediaDownloadMetadataStore {
    func fileURL(for id: MediaDownload.ID) throws -> URL {
        try directoryURL.creatingIfNeeded()
            .appendingPathComponent(id)
            .appendingPathExtension("plist")
    }
}

private extension PropertyListEncoder {
    static let metaStore = PropertyListEncoder()
}

private extension PropertyListDecoder {
    static let metaStore = PropertyListDecoder()
}
