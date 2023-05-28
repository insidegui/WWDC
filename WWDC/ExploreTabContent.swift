import SwiftUI

struct ExploreTabContent: Codable {
    struct Item: Identifiable, Codable {
        var id: String
        var title: String
        var subtitle: String?
        var overlayText: String?
        var overlaySymbol: String?
        var imageURL: URL?
        var deepLink: URL?
        var progress: Double?
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
            imageURL: URL(string: "https://wwdc.io/images/placeholder.jpg")!,
            deepLink: nil
        ),
        .init(
            id: "2",
            title: "Placeholder",
            subtitle: "Placeholder Item Description 2",
            overlayText: "25m",
            overlaySymbol: "play",
            imageURL: URL(string: "https://wwdc.io/images/placeholder.jpg")!,
            deepLink: nil
        ),
        .init(
            id: "3",
            title: "Placeholder Item Longer Title",
            subtitle: "Placeholder Item Description 3",
            overlayText: "35m",
            overlaySymbol: "play",
            imageURL: URL(string: "https://wwdc.io/images/placeholder.jpg")!,
            deepLink: nil
        )
    ]
}

extension ExploreTabContent {
    static let placeholder: ExploreTabContent = {
        ExploreTabContent(id: "1", sections: [
            Section(id: "placeholder-1", title: "Placeholder Section First", icon: .symbol("app.badge.checkmark"), items: ExploreTabContent.Item.placeholderItems),
            Section(id: "placeholder-2", title: "Placeholder Section Second Longer Title", icon: .symbol("app.badge.checkmark"), items: ExploreTabContent.Item.placeholderItems),
            Section(id: "placeholder-3", title: "Placeholder Short", icon: .symbol("app.badge.checkmark"), items: ExploreTabContent.Item.placeholderItems)
        ])
    }()
}

// MARK: - Preview Support

#if DEBUG

extension ExploreTabContent {
    static let preview: ExploreTabContent = {
        guard let data = NSDataAsset(name: "ExploreTab")?.data else {
            fatalError("Missing ExploreTab development asset")
        }
        do {
            return try JSONDecoder().decode(ExploreTabContent.self, from: data)
        } catch {
            fatalError("Failed to decode ExploreTab development asset: \(error)")
        }
    }()

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
