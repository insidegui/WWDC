import Foundation
import ConfCore

extension SessionAssetType: DownloadableMediaVariant { }

extension Session {
    func asset(for variant: SessionAssetType) -> SessionAsset? { assets(matching: [variant]).first }
}

extension Session {
    var mediaContainer: SessionMediaContainer { SessionMediaContainer(session: self) }
}

struct SessionMediaContainer: DownloadableMediaContainer {
    struct AssetStub {
        var relativeLocalPath: String
        var remoteURL: URL
    }

    typealias MediaVariant = SessionAssetType

    private(set) var id: String
    private(set) var title: String
    private(set) var assets: [MediaVariant: AssetStub]

    init(session: Session) {
        self.id = session.identifier
        self.assets = [:]
        self.title = session.title

        if let hdVideo = session.asset(for: .hdVideo),
           let remoteURL = URL(string: hdVideo.remoteURL)
        {
            assets[.hdVideo] = AssetStub(relativeLocalPath: hdVideo.relativeLocalURL, remoteURL: remoteURL)
        }
        if let hlsVideo = session.asset(for: .downloadHLSVideo),
           let remoteURL = URL(string: hlsVideo.remoteURL)
        {
            assets[.downloadHLSVideo] = AssetStub(relativeLocalPath: hlsVideo.relativeLocalURL, remoteURL: remoteURL)
        }
    }

    public var downloadIdentifier: String { id }

    public static var mediaDownloadVariants: [MediaVariant] {
        Preferences.shared.preferHLSVideoDownload ? [.downloadHLSVideo, .hdVideo] : [.hdVideo, .downloadHLSVideo]
    }

    public func relativeLocalPath(for variant: MediaVariant) -> String? { assets[variant]?.relativeLocalPath }

    public func remoteDownloadURL(for variant: MediaVariant) -> URL? { assets[variant]?.remoteURL }
}

extension Session: DownloadableMediaContainer {
    public typealias MediaVariant = SessionAssetType

    public var downloadIdentifier: String { mediaContainer.downloadIdentifier }

    public static var mediaDownloadVariants: [SessionAssetType] { SessionMediaContainer.mediaDownloadVariants }

    public func relativeLocalPath(for variant: SessionAssetType) -> String? { mediaContainer.relativeLocalPath(for: variant) }

    public func remoteDownloadURL(for variant: SessionAssetType) -> URL? { mediaContainer.remoteDownloadURL(for: variant) }
}
