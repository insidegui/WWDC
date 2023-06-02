import SwiftUI

struct ExploreTabContent: Codable {
    struct Item: Identifiable, Codable {
        enum Destination: Codable {
            case url(URL)
            case command(WWDCAppCommand)
        }
        struct LiveStream: Codable {
            var startTime: Date
            var endTime: Date
            var url: URL?
        }
        var id: String
        var title: String
        var subtitle: String?
        var overlayText: String?
        var overlaySymbol: String?
        var imageURL: URL?
        var destination: Destination?
        var progress: Double?
        var liveStream: LiveStream?
    }

    struct Section: Identifiable, Codable {
        enum Layout: Codable {
            case card
            case pill
        }
        enum Icon: Codable {
            case symbol(String)
            case remoteGlyph(URL)
        }
        var id: String
        var title: String
        var layout: Layout = .card
        var icon: Icon
        var items: [Item]
    }

    var id: String
    var sections: [Section]
    var liveEventItem: Item?
}

// MARK: - Placeholder Content

extension ExploreTabContent.Item {
    static let placeholderItems: [ExploreTabContent.Item] = [
        .init(
            id: "1",
            title: "Placeholder Item Regular",
            subtitle: "Placeholder Item Description 1",
            overlayText: "20m",
            overlaySymbol: "play",
            imageURL: URL(string: "https://wwdc.io/images/placeholder.jpg")!
        ),
        .init(
            id: "2",
            title: "Placeholder",
            subtitle: "Placeholder Item Description 2",
            overlayText: "25m",
            overlaySymbol: "play",
            imageURL: URL(string: "https://wwdc.io/images/placeholder.jpg")!
        ),
        .init(
            id: "3",
            title: "Placeholder Item Longer Title",
            subtitle: "Placeholder Item Description 3",
            overlayText: "35m",
            overlaySymbol: "play",
            imageURL: URL(string: "https://wwdc.io/images/placeholder.jpg")!
        )
    ]
    static let placeholderItems2: [ExploreTabContent.Item] = [
        .init(
            id: "4",
            title: "Placeholder Item Regular",
            subtitle: "Placeholder Description 4",
            overlayText: "24m",
            overlaySymbol: "play",
            imageURL: URL(string: "https://wwdc.io/images/placeholder.jpg")!
        ),
        .init(
            id: "5",
            title: "Placeholder",
            subtitle: "Placeholder Item Description 5",
            overlayText: "37m",
            overlaySymbol: "play",
            imageURL: URL(string: "https://wwdc.io/images/placeholder.jpg")!
        ),
        .init(
            id: "6",
            title: "Placeholder Item Longer Title",
            subtitle: "Placeholder Item Description 6",
            overlayText: "37m",
            overlaySymbol: "play",
            imageURL: URL(string: "https://wwdc.io/images/placeholder.jpg")!
        ),
        .init(
            id: "7",
            title: "Placeholder",
            subtitle: "Item Description 7",
            overlayText: "35m",
            overlaySymbol: "play",
            imageURL: URL(string: "https://wwdc.io/images/placeholder.jpg")!
        )
    ]
}

extension ExploreTabContent {
    static let placeholder: ExploreTabContent = {
        ExploreTabContent(id: "1", sections: [
            Section(id: "placeholder-1", title: "Placeholder Section First", icon: .symbol("app.badge.checkmark"), items: ExploreTabContent.Item.placeholderItems),
            Section(id: "placeholder-2", title: "Placeholder Section Second Longer Title", icon: .symbol("app.badge.checkmark"), items: ExploreTabContent.Item.placeholderItems2),
            Section(id: "placeholder-3", title: "Placeholder Short", icon: .symbol("app.badge.checkmark"), items: ExploreTabContent.Item.placeholderItems)
        ])
    }()
}

// MARK: - Preview Support

#if DEBUG

extension ExploreTabContent {
    static let preview: ExploreTabContent = preview(named: "ExploreTab")
    static let previewLiveSoon: ExploreTabContent = preview(named: "ExploreTab-Live")
    static let previewLiveCurrent: ExploreTabContent = preview(named: "ExploreTab-Live-Current")

    private static func preview(named name: String) -> Self {
        guard let data = NSDataAsset(name: name)?.data else {
            fatalError("Missing \(name) development asset")
        }
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(ExploreTabContent.self, from: data)
        } catch {
            fatalError("Failed to decode \(name) development asset: \(error)")
        }
    }

    func exportJSON() {
        do {
            let json = try JSONEncoder().encode(self)

            let panel = NSSavePanel()
            panel.prompt = "Export"
            panel.nameFieldStringValue = "ExploreTab"
            panel.allowedContentTypes = [.json]
            guard panel.runModal() == .OK, let url = panel.url else { return }

            try json.write(to: url)
        } catch {
            NSAlert(error: error).runModal()
        }
    }
}

#endif
