//
//  CommunityCollectionViewController.swift
//  WWDC
//
//  Created by Guilherme Rambo on 31/05/20.
//  Copyright © 2020 Guilherme Rambo. All rights reserved.
//

import Cocoa
import ConfCore
import RxSwift
import RxCocoa
import RealmSwift

fileprivate extension NSUserInterfaceItemIdentifier {
    static let communityItem = NSUserInterfaceItemIdentifier(rawValue: "communityItemCell")
    static let communityEditionItem = NSUserInterfaceItemIdentifier(rawValue: "communityEditionCell")
    static let communitySectionHeader = NSUserInterfaceItemIdentifier(rawValue: "communitySectionHeader")
}

final class CommunityCollectionViewController: NSViewController {

    enum Section: Int, CaseIterable {
        case newsItems
        case editions
    }

    var newsItems: Results<CommunityNewsItem>? {
        didSet {
            reloadData()
        }
    }

    var editions: Results<CocoaHubEdition>? {
        didSet {
            reloadData()
        }
    }

    static func makeHeaderLayoutItem() -> NSCollectionLayoutBoundarySupplementaryItem {
        let size = NSCollectionLayoutSize(widthDimension: .fractionalWidth(0.95), heightDimension: .absolute(88))

        let item = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: size,
            elementKind: NSCollectionView.elementKindSectionHeader,
            alignment: .topLeading
        )

        item.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 0)

        return item
    }

    static func makeLayout() -> NSCollectionViewLayout {
        NSCollectionViewCompositionalLayout { index, env in
            let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .fractionalHeight(1))

            let layoutItem = NSCollectionLayoutItem(layoutSize: itemSize)
            layoutItem.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 22)

            let layoutGroupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(0.3), heightDimension: .absolute(200))

            let group = NSCollectionLayoutGroup.vertical(layoutSize: layoutGroupSize, subitem: layoutItem, count: 1)

            let section = NSCollectionLayoutSection(group: group)

            section.boundarySupplementaryItems = [Self.makeHeaderLayoutItem()]
            section.orthogonalScrollingBehavior = .continuous
            section.contentInsets = NSDirectionalEdgeInsets(top: 34, leading: 60, bottom: 22, trailing: 0)

            return section
        }
    }

    private lazy var collectionView: NSCollectionView = {
        let v = NSCollectionView()

        v.translatesAutoresizingMaskIntoConstraints = false
        v.collectionViewLayout = Self.makeLayout()
        v.backgroundColors = []
        v.dataSource = self
        v.delegate = self

        return v
    }()

    private let disposeBag = DisposeBag()

    override func loadView() {
        view = NSView()
        view.wantsLayer = true
        view.addSubview(collectionView)

        NSLayoutConstraint.activate([
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        collectionView.register(CommunityCollectionViewItem.self, forItemWithIdentifier: .communityItem)
        collectionView.register(CommunityCollectionViewItem.self, forItemWithIdentifier: .communityEditionItem)
        collectionView.register(CommunitySectionHeaderView.self, forSupplementaryViewOfKind: NSCollectionView.elementKindSectionHeader, withIdentifier: .communitySectionHeader)
    }

    private func reloadData() {
        NSObject.cancelPreviousPerformRequests(withTarget: collectionView, selector: #selector(NSCollectionView.reloadData), object: nil)
        collectionView.perform(#selector(NSCollectionView.reloadData), with: nil, afterDelay: 0.1)
    }
    
}

extension CommunityCollectionViewController: NSCollectionViewDataSource, NSCollectionViewDelegate {

    func numberOfSections(in collectionView: NSCollectionView) -> Int { Section.allCases.count }

    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        guard let contentSection = Section(rawValue: section) else {
            preconditionFailure("Invalid section \(section)")
        }

        switch contentSection {
        case .newsItems:
            return newsItems?.count ?? 0
        case .editions:
            return editions?.count ?? 0
        }
    }

    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        guard let contentSection = Section(rawValue: indexPath.section) else {
            preconditionFailure("Invalid section \(indexPath.section)")
        }

        let identifier: NSUserInterfaceItemIdentifier

        switch contentSection {
        case .newsItems:
            identifier = .communityItem
        case .editions:
            identifier = .communityEditionItem
        }

        guard let cell = collectionView.makeItem(withIdentifier: identifier, for: indexPath) as? CommunityCollectionViewItem else {
            preconditionFailure("Invalid cell")
        }

        switch contentSection {
        case .newsItems:
            cell.newsItem = newsItems?[indexPath.item]
        case .editions:
            break
        }

        return cell
    }

    func collectionView(_ collectionView: NSCollectionView, viewForSupplementaryElementOfKind kind: NSCollectionView.SupplementaryElementKind, at indexPath: IndexPath) -> NSView {
        guard let contentSection = Section(rawValue: indexPath.section) else {
            preconditionFailure("Invalid section \(indexPath.section)")
        }

        guard let headerView = collectionView.makeSupplementaryView(ofKind: kind, withIdentifier: .communitySectionHeader, for: indexPath) as? CommunitySectionHeaderView else {
            return NSView()
        }

        switch contentSection {
        case .newsItems:
            headerView.title = "Latest News"
        case .editions:
            headerView.title = "CocoaHub Editions"
        }

        return headerView
    }

}
