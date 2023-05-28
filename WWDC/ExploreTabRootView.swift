import SwiftUI
import ConfCore
import ConfUIFoundation

struct ExploreTabRootView: View {
    @EnvironmentObject private var provider: ExploreTabProvider

    var body: some View {
        if let content = provider.content {
            ExploreTabContentView(content: content, scrollOffset: $provider.scrollOffset)
                #if DEBUG
                .contextMenu { Button("Export JSON…", action: content.exportJSON) }
                #endif
        } else {
            ExploreTabContentView(content: .placeholder, scrollOffset: .constant(.zero))
                .redacted(reason: .placeholder)
        }
    }

}

private struct ExploreTabContentView: View {
    var content: ExploreTabContent

    @Binding var scrollOffset: CGPoint

    var body: some View {
        OffsetObservingScrollView(axes: [.vertical], showsIndicators: true, offset: $scrollOffset) {
            LazyVStack(alignment: .leading, spacing: 42) {
                ForEach(content.sections) { section in
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 6) {
                            section.icon

                            Text(section.title)
                        }
                        .padding(.horizontal)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .padding(.leading, 2)
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(alignment: .top, spacing: 16) {
                                ForEach(section.items) { item in
                                    ExploreTabItem(layout: section.layout, item: item)
                                        .contentShape(Rectangle())
                                        .onTapGesture { open(item) }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
            }
            .padding(.vertical)
        }
    }

    private func open(_ item: ExploreTabContent.Item) {
        guard let destination = item.destination else {
            return
        }

        switch destination {
        case .command(let command):
            AppDelegate.run(command)
        case .url(let url):
            NSWorkspace.shared.open(url)
        }
    }
}

extension ExploreTabContent.Section.Icon: View {
    var body: some View {
        switch self {
        case .symbol(let name):
            Image(systemName: name)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .symbolVariant(.fill)
                .frame(width: 22, height: 16)
        case .remoteGlyph(let url):
            RemoteGlyph(url: url)
                .frame(width: 22, height: 22)
        }
    }
}

private struct ExploreTabItem: View {
    var layout: ExploreTabContent.Section.Layout
    var item: ExploreTabContent.Item
    var width: CGFloat = 240
    var imageHeight: CGFloat = 200

    var body: some View {
        Group {
            switch layout {
            case .card:
                CardLayout(item: item, imageHeight: imageHeight)
                    .frame(width: width)
            case .pill:
                PillLayout(item: item)
            }
        }
    }

    private struct CardLayout: View {
        var item: ExploreTabContent.Item
        var imageHeight: CGFloat = 200

        private var overlayAlignment: Alignment {
            item.progress != nil ? .topTrailing : .bottomTrailing
        }

        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                thumbnail
                    .overlay(alignment: overlayAlignment) {
                        HStack(spacing: 4) {
                            if let symbolName = item.overlaySymbol {
                                Image(systemName: symbolName)
                                    .symbolVariant(.fill)
                            }
                            if let text = item.overlayText {
                                Text(text)
                            }
                        }
                        .font(.caption.weight(.medium))
                        .padding(.vertical, 4)
                        .padding(.horizontal, 6)
                        .background(Material.thin, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                        .padding(4)
                    }
                    .overlay(alignment: .bottom) {
                        if let progress = item.progress {
                            MiniProgressBar(progress: progress)
                        }
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.system(.subheadline).weight(.medium))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    if let subtitle = item.subtitle {
                        Text(subtitle)
                            .lineLimit(2)
                            .font(.system(.headline).weight(.medium))
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.leading, 2)
            }
        }

        @ViewBuilder
        private var thumbnail: some View {
            if let url = item.imageURL {
                RemoteImage(url: url, thumbnailHeight: imageHeight) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                } placeholder: {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .foregroundStyle(.quaternary)
                }
                .frame(width: 236, height: 134)
            }
        }
    }

    private struct PillLayout: View {
        var item: ExploreTabContent.Item

        var body: some View {
            HStack {
                if let name = item.overlaySymbol {
                    Image(systemName: name)
                }
                Text(item.title)
            }
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .padding(.horizontal)
                .frame(maxWidth: .infinity, minHeight: 48, maxHeight: 48)
                .background(Color(nsColor: .quaternaryLabelColor), in: shape)
                .overlay {
                    shape
                        .strokeBorder(Color.black.opacity(0.2))
                }
        }

        private var shape: some InsettableShape {
            Capsule(style: .continuous)
        }
    }
}

private struct MiniProgressBar: View {
    var progress: Double

    var body: some View {
        Rectangle()
            .foregroundStyle(Material.thin)
            .frame(height: 6)
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    Rectangle()
                        .foregroundStyle(Color.white.opacity(0.7))
                        .frame(width: proxy.size.width * progress)
                        .blendMode(.plusLighter)
                }
            }
            .clipShape(Capsule(style: .continuous))
            .padding(6)
    }
}

#if DEBUG
struct ExploreTabContentView_Previews: PreviewProvider {
    static var previews: some View {
        ExploreTabContentView(content: .preview, scrollOffset: .constant(.zero))
            .frame(minWidth: 700, maxWidth: .infinity, minHeight: 2000, maxHeight: .infinity)
    }
}
#endif
