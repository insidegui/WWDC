import SwiftUI

@MainActor
struct ExploreTabRootView: View {
    @EnvironmentObject private var provider: ExploreTabProvider

    var body: some View {
        ZStack {
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
        .animation(.spring(), value: provider.content?.sections.flatMap(\.items).count)
    }

}

@MainActor
struct ExploreTabContentView: View {
    static let cardImageCornerRadius: CGFloat = 8
    static let cardWidth: CGFloat = 240
    static let cardImageHeight: CGFloat = 134

    var content: ExploreTabContent

    @Binding var scrollOffset: CGPoint

    @State private var isPresentingLiveEvent = false

    var body: some View {
        scrollView
            .overlay {
                if let liveItem = content.liveEventItem, isPresentingLiveEvent {
                    LiveStreamOverlay(item: liveItem) {
                        isPresentingLiveEvent = false
                    }
                    .animation(.default, value: content.isLiveEventStreaming)
                }
            }
            .onAppear {
                /// Automatically present live event item when even is currently live
                if content.isLiveEventStreaming {
                    isPresentingLiveEvent = true
                }
            }
    }

    @ViewBuilder
    private var scrollView: some View {
        OffsetObservingScrollView(axes: [.vertical], showsIndicators: true, offset: $scrollOffset) {
            LazyVStack(alignment: .leading, spacing: 42) {
                liveHeader

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
                                    ExploreTabItemView(layout: section.layout, item: item)
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
            .blur(radius: isPresentingLiveEvent ? 24 : 0)
        }
    }

    @ViewBuilder
    private var liveHeader: some View {
        if let liveItem = content.liveEventItem {
            ExploreTabItemView(layout: .card, item: liveItem)
                .padding(.horizontal)
                .onTapGesture {
                    isPresentingLiveEvent = true
                }
        }
    }

    @MainActor
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

#if DEBUG
struct ExploreTabContentView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ExploreTabContentView(content: .previewLiveCurrent, scrollOffset: .constant(.zero))
        }
            .frame(minWidth: 900, maxWidth: .infinity, minHeight: 700, maxHeight: .infinity)
    }
}
#endif
