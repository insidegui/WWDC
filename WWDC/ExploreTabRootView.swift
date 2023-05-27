//
//  ExploreTabRootView.swift
//  WWDC
//
//  Created by Guilherme Rambo on 26/05/23.
//  Copyright © 2023 Guilherme Rambo. All rights reserved.
//

import SwiftUI
import ConfCore
import ConfUIFoundation

struct ExploreTabContent {
    struct Item: Identifiable {
        var id: String
        var title: String
        var subtitle: String?
        var overlayText: String?
        var overlaySymbol: String?
        var imageURL: URL?
        var deepLink: URL?
    }

    struct Section: Identifiable {
        enum Icon {
            case symbol(String)
            case remoteGlyph(URL)
        }
        var id: String
        var title: String
        var icon: Icon
        var items: [Item]
    }

    var id: String
    var sections: [Section]
}

struct ExploreTabRootView: View {
    @EnvironmentObject private var provider: ExploreTabProvider

    var body: some View {
        if let content = provider.content {
            ExploreTabContentView(content: content, scrollOffset: $provider.scrollOffset)
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
                                    ExploreTabItem(item: item)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            if let url = item.deepLink {
                                                NSWorkspace.shared.open(url)
                                            }
                                        }
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
    var item: ExploreTabContent.Item

    var width: CGFloat = 240
    var imageHeight: CGFloat = 200

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            thumbnail
                .overlay(alignment: .bottomTrailing) {
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
        .frame(width: width)
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

private struct RemoteImage<Content: View, Placeholder: View>: View {
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

#if DEBUG
// swiftlint:disable all

struct ExploreTabContentView_Previews: PreviewProvider {
    static var previews: some View {
        ExploreTabContentView(content: .preview, scrollOffset: .constant(.zero))
            .frame(minWidth: 700, maxWidth: .infinity, minHeight: 600, maxHeight: .infinity)
    }
}

extension ExploreTabContent.Item {
    static let previews: [ExploreTabContent.Item] = [
        .init(
            id: "1",
            title: "Tech Talks",
            subtitle: "Measure and improve acquisition with App Analytics",
            overlayText: "20m",
            overlaySymbol: "play",
            imageURL: URL(string: "https://devimages-cdn.apple.com/wwdc-services/images/8/8392/8392_wide_900x506_1x.jpg")!,
            deepLink: URL(string: "wwdc://1")!
        ),
        .init(
            id: "2",
            title: "WWDC22",
            subtitle: "Compose advanced models with Create ML Components",
            overlayText: "13m",
            overlaySymbol: "play",
            imageURL: URL(string: "https://devimages-cdn.apple.com/wwdc-services/images/124/6513/6513_wide_900x506_1x.jpg")!,
            deepLink: URL(string: "wwdc://2")!
        ),
        .init(
            id: "3",
            title: "Tech Talks",
            subtitle: "Measure and improve acquisition with App Analytics",
            overlayText: "20m",
            overlaySymbol: "play",
            imageURL: URL(string: "https://devimages-cdn.apple.com/wwdc-services/images/8/8392/8392_wide_900x506_1x.jpg")!,
            deepLink: URL(string: "wwdc://1")!
        ),
        .init(
            id: "4",
            title: "WWDC22",
            subtitle: "Compose advanced models with Create ML Components",
            overlayText: "13m",
            overlaySymbol: "play",
            imageURL: URL(string: "https://devimages-cdn.apple.com/wwdc-services/images/124/6513/6513_wide_900x506_1x.jpg")!,
            deepLink: URL(string: "wwdc://2")!
        ),
    ]
}

extension ExploreTabContent {
    static let preview: ExploreTabContent = {
        ExploreTabContent(id: "1", sections: [
            Section(id: "continue-watching", title: "Continue Watching", icon: .symbol("app.badge.checkmark"), items: ExploreTabContent.Item.previews),
            Section(id: "tech-talks", title: "Tech Talks", icon: .remoteGlyph(URL(string: "https://devimages-cdn.apple.com/wwdc-services/images/topic-glyphs/Source-TechTalks.pdf")!), items: ExploreTabContent.Item.previews),
            Section(id: "favorites", title: "Your Favorites", icon: .symbol("star"), items: ExploreTabContent.Item.previews),
        ])
    }()
}

// swiftlint:enable all
#endif

extension ExploreTabContent.Item {
    static let placeholderItems: [ExploreTabContent.Item] = [
        .init(
            id: "1",
            title: "Placeholder Item Regular",
            subtitle: "Placeholder Item Description 1",
            overlayText: "20m",
            overlaySymbol: "play",
            imageURL: nil,
            deepLink: nil
        ),
        .init(
            id: "2",
            title: "Placeholder",
            subtitle: "Placeholder Item Description 2",
            overlayText: "25m",
            overlaySymbol: "play",
            imageURL: nil,
            deepLink: nil
        ),
        .init(
            id: "3",
            title: "Placeholder Item Longer Title",
            subtitle: "Placeholder Item Description 3",
            overlayText: "35m",
            overlaySymbol: "play",
            imageURL: nil,
            deepLink: nil
        ),
    ]
}

extension ExploreTabContent {
    static let placeholder: ExploreTabContent = {
        ExploreTabContent(id: "1", sections: [
            Section(id: "placeholder-1", title: "Placeholder Section First", icon: .symbol("app.badge.checkmark"), items: ExploreTabContent.Item.placeholderItems),
            Section(id: "placeholder-2", title: "Placeholder Section Second Longer Title", icon: .symbol("app.badge.checkmark"), items: ExploreTabContent.Item.placeholderItems),
            Section(id: "placeholder-3", title: "Placeholder Short", icon: .symbol("app.badge.checkmark"), items: ExploreTabContent.Item.placeholderItems),
        ])
    }()
}
