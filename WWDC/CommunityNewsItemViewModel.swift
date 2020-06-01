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

struct CommunityTagViewModel: Hashable {

    let name: String
    let title: String
    let order: Int
    let color: NSColor

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
    let isFeatured: Bool
    let image: URL?

}

extension CommunityTagViewModel {
    init(tag: CommunityTag) {
        self.init(
            name: tag.name,
            title: tag.title,
            order: tag.order,
            color: NSColor.fromHexString(hexString: tag.color)
        )
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
                title: tag.title,
                color: tag.color,
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
            isFeatured: item.isFeatured,
            image: item.image.flatMap(URL.init)
        )
    }

}
