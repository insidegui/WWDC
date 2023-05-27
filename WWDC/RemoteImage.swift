import SwiftUI

struct RemoteImage<Content: View, Placeholder: View>: View {
    var url: URL
    var thumbnailHeight: CGFloat = 200
    @ViewBuilder var content: (SwiftUI.Image) -> Content
    @ViewBuilder var placeholder: () -> Placeholder

    @State private var image: NSImage?

    var body: some View {
        if let image = ImageDownloadCenter.shared.cachedThumbnail(from: url) ?? self.image {
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
            ImageDownloadCenter.shared.downloadImage(from: url, thumbnailHeight: thumbnailHeight, thumbnailOnly: true) { _, result in
                continuation.resume(returning: result.thumbnail)
            }
        }
    }
}
