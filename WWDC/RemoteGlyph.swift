import SwiftUI

struct RemoteGlyph: View {
    var url: URL?

    @State private var image: NSImage?

    private var displayImage: NSImage? {
        guard let url else { return nil }
        return cache.cachedImage(for: url, thumbnailOnly: false).original ?? image
    }

    var body: some View {
        if let displayImage {
            Image(nsImage: displayImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            if let url {
                Rectangle()
                    .opacity(0)
                    .task(id: url) {
                        await load(url)
                    }
            } else {
                Rectangle()
                    .opacity(0)
            }
        }
    }

    private let cache = ImageDownloadCenter.shared.cache

    private func load(_ url: URL) async {
        guard let (data, res) = try? await URLSession.shared.data(from: url) else { return }

        guard (res as? HTTPURLResponse)?.statusCode == 200 else { return }

        guard let loadedImage = NSImage(data: data) else { return }

        loadedImage.isTemplate = true

        self.image = loadedImage

        cache.cacheImage(for: url, original: nil, completion: { _ in })
    }

}

#if DEBUG
struct RemoteGlyph_Previews: PreviewProvider, View {
    static var previews: some View { Self() }

    @State private var removed = false

    var body: some View {
        VStack {
            if !removed {
                RemoteGlyph(url: URL(string: "https://devimages-cdn.apple.com/wwdc-services/images/topic-glyphs/rd7a2338/wwdc.badge.outline.pdf")!)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 32, height: 32)
                    .foregroundColor(.accentColor)

                Text("Tap to Toggle")
            }
        }
        .padding()
        .frame(minWidth: 200, minHeight: 200)
        .contentShape(Rectangle())
        .onTapGesture {
            removed.toggle()
        }
    }}
#endif
