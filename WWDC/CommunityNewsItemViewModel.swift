//
//  CommunityNewsItemViewModel.swift
//  WWDC
//
//  Created by Guilherme Rambo on 01/06/20.
//  Copyright © 2020 Guilherme Rambo. All rights reserved.
//

import Cocoa
import ConfCore
import RealmSwift

struct CommunityTagViewModel: Hashable, RawRepresentable {

    typealias RawValue = String

    var rawValue: String

    var order: Int

    var color: NSColor?

    init(rawValue: String) {
        self.rawValue = rawValue
        self.order = Self.defaultOrder(for: rawValue)
        self.color = NSColor(named: .init("tagColor-" + rawValue))
    }

    var displayName: String {
        switch rawValue {
        case "apple": return "Apple"
        case "community": return "Community"
        case "evolution": return "Evolution"
        case "press": return "Press"
        case "podcast": return "Podcast"
        case "newsletter": return "Newsletter"
        case "sundell": return "WWDC by Sundell & Friends"
        default: return ""
        }
    }

    static func defaultOrder(for value: String) -> Int {
        switch value {
        case "apple": return 0
        case "community": return 1
        case "podcast": return 2
        case "sundell": return 3
        case "evolution": return 4
        case "press": return 5
        default: return 99
        }
    }
}

struct CommunitySection: Hashable {
    let tag: CommunityTagViewModel
    let title: String
    let color: NSColor
    let items: [CommunityNewsItemViewModel]
}

struct CommunityNewsItemViewModel: Hashable {

    let id: String
    let title: String
    let attributedSummary: NSAttributedString?
    let tag: CommunityTagViewModel
    let url: URL
    let date: Date
    let formattedDate: String
    let image: URL?

}

extension CommunityTagViewModel {
    init(tag: CommunityTag) {
        self = CommunityTagViewModel(rawValue: tag.name)
        color = NSColor.fromHexString(hexString: tag.color)
        order = tag.order
    }
}

extension CommunitySection {

    static func sections(from results: Results<CommunityNewsItem>) -> [CommunitySection] {
        var groups: [CommunityTagViewModel: [CommunityNewsItemViewModel]] = [:]

        results.forEach { item in
            guard let rawTag = item.tags.first else { return }

            let tag = CommunityTagViewModel(tag: rawTag)

            guard let viewModel = CommunityNewsItemViewModel(item: item) else {
                assertionFailure("Expected view model creation to succeed")
                return
            }

            if groups[tag] != nil {
                groups[tag]?.append(viewModel)
            } else {
                groups[tag] = [viewModel]
            }
        }

        return groups.keys.sorted(by: { $0.order < $1.order }).map { tag in
            CommunitySection(
                tag: tag,
                title: tag.displayName,
                color: tag.color ?? .systemGray,
                items: groups[tag] ?? []
            )
        }
    }

}

extension CommunityNewsItemViewModel {

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()

        f.dateStyle = .short
        f.timeStyle = .none
        f.doesRelativeDateFormatting = true

        return f
    }()

    private static func attributedSummary(from summary: String?) -> NSAttributedString? {
        guard let summary = summary else { return nil }

        return NSAttributedString.create(
            with: summary,
            font: .systemFont(ofSize: 14),
            color: .secondaryText,
            lineHeightMultiple: 1.28
        )
    }

    init?(item: CommunityNewsItem) {
        guard let url = URL(string: item.url) else {
            assertionFailure("Expected string to be a valid URL: \(item.url)")
            return nil
        }
        guard let rawTag = item.tags.first else {
            assertionFailure("News item must have at least one tag")
            return nil
        }

        self.init(
            id: item.id,
            title: item.title,
            attributedSummary: Self.attributedSummary(from: item.summary),
            tag: CommunityTagViewModel(tag: rawTag),
            url: url,
            date: item.date,
            formattedDate: Self.dateFormatter.string(from: item.date),
            image: item.image.flatMap(URL.init)
        )
    }

}
