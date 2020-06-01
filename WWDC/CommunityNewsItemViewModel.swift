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

enum CommunityTag: String {
    case apple
    case community
    case evolution
    case press
    case podcast
    case newsletter
    case sundell

    var displayName: String {
        switch self {
        case .apple: return "Apple"
        case .community: return "Community"
        case .evolution: return "Evolution"
        case .press: return "Press"
        case .podcast: return "Podcast"
        case .newsletter: return "Newsletter"
        case .sundell: return "WWDC by Sundell & Friends"
        }
    }

    var color: NSColor? { NSColor(named: .init("tagColor-" + rawValue)) }
}

struct CommunitySection: Hashable {
    let tag: CommunityTag
    let title: String
    let color: NSColor
    let items: [CommunityNewsItemViewModel]
}

struct CommunityNewsItemViewModel: Hashable {

    let id: String
    let title: String
    let attributedSummary: NSAttributedString?
    let tag: String?
    let url: URL
    let date: Date
    let formattedDate: String

}

extension CommunitySection {

    static func sections(from results: Results<CommunityNewsItem>) -> [CommunitySection] {
        var groups: [CommunityTag: [CommunityNewsItemViewModel]] = [:]

        results.forEach { item in
            guard let rawTag = item.tags.first, let tag = CommunityTag(rawValue: rawTag) else { return }

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

        return groups.keys.map { tag in
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

        self.init(
            id: item.id,
            title: item.title,
            attributedSummary: Self.attributedSummary(from: item.summary),
            tag: item.tags.first,
            url: url,
            date: item.date,
            formattedDate: Self.dateFormatter.string(from: item.date)
        )
    }

}
