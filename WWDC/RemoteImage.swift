import SwiftUI

struct RemoteImage<Content: View, Placeholder: View>: View {
    enum Size: Hashable {
        case thumbnail(height: CGFloat)
        case large
    }
    var url: URL
    var size: Size
    @ViewBuilder var content: (SwiftUI.Image) -> Content
    @ViewBuilder var placeholder: () -> Placeholder

    @State private var image: NSImage?

    private var isThumbnail: Bool {
        guard case .thumbnail = size else { return false }
        return true
    }

    var body: some View {
        if isThumbnail, let image = ImageDownloadCenter.shared.cachedThumbnail(from: url) ?? self.image {
            content(Image(nsImage: image))
        } else {
            placeholder()
                .task(id: url) {
                    self.image = await load()
                }
        }
    }

    private func load() async -> NSImage? {
        await withCheckedContinuation { continuation in
            switch size {
            case .thumbnail(let height):
                ImageDownloadCenter.shared.downloadImage(from: url, thumbnailHeight: height, thumbnailOnly: true) { _, result in
                    continuation.resume(returning: result.thumbnail)
                }
            case .large:
                ImageDownloadCenter.shared.downloadImage(from: url, thumbnailHeight: 400, thumbnailOnly: true) { _, result in
                    continuation.resume(returning: result.original)
                }
            }

        }
    }
}
