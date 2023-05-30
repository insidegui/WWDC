import SwiftUI

struct ExploreTabItemView: View {
    var layout: ExploreTabContent.Section.Layout
    var item: ExploreTabContent.Item
    var width: CGFloat = ExploreTabContentView.cardWidth
    var imageHeight: CGFloat = ExploreTabContentView.cardImageHeight

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
        .contentShape(Rectangle())
    }

    private struct CardLayout: View {
        var item: ExploreTabContent.Item
        var imageHeight: CGFloat = 200

        private var overlayAlignment: Alignment {
            item.progress != nil ? .topTrailing : .bottomTrailing
        }

        private var hasOverlay: Bool { item.overlayText != nil || item.overlaySymbol != nil }

        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                thumbnail
                    .overlay(alignment: overlayAlignment) {
                        overlayContent
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
        private var overlayContent: some View {
            if hasOverlay {
                HStack(spacing: 4) {
                    if let symbolName = item.overlaySymbol {
                        Image(systemName: symbolName)
                            .symbolVariant(.fill)
                    }
                    if let text = item.overlayText {
                        Text(text)
                    }
                }
                .foregroundColor(item.isLiveStreaming ? .red : .primary)
                .font(.caption.weight(.medium))
                .padding(.vertical, 4)
                .padding(.horizontal, 6)
                .background(Material.thin, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                .padding(4)
            }
        }

        @ViewBuilder
        private var thumbnail: some View {
            if let url = item.imageURL {
                RemoteImage(url: url, size: .thumbnail(height: imageHeight)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .clipShape(RoundedRectangle(cornerRadius: ExploreTabContentView.cardImageCornerRadius, style: .continuous))
                } placeholder: {
                    RoundedRectangle(cornerRadius: ExploreTabContentView.cardImageCornerRadius, style: .continuous)
                        .foregroundStyle(.quaternary)
                }
                .frame(width: 236, height: ExploreTabContentView.cardImageHeight)
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

extension ExploreTabContent {
    /// Live overlay auto-opens when current time is within the event's time interval and it has a live streaming URL.
    var isLiveEventStreaming: Bool { liveEventItem?.isLiveStreaming == true }
}

extension ExploreTabContent.Item {
    var isLiveStreaming: Bool {
        guard let liveStream else { return false }
        guard liveStream.url != nil else { return false }
        return liveStream.startTime <= today() && liveStream.endTime > today().addingTimeInterval(60 * 50)
    }
}

#if DEBUG
struct ExploreTabItemView_Previews: PreviewProvider {
    static var previews: some View {
        ExploreTabContentView_Previews.previews
    }
}
#endif
