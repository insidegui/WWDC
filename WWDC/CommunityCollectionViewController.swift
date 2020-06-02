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
    static let communityFeaturedItem = NSUserInterfaceItemIdentifier(rawValue: "communityFeaturedCell")
    static let communitySectionHeader = NSUserInterfaceItemIdentifier(rawValue: "communitySectionHeader")
}

final class CommunityCollectionViewController: NSViewController {

    var didSelectItem: (CommunityNewsItemViewModel) -> Void = { _ in }

    enum Section: Int, CaseIterable {
        case newsItems
        case editions
    }

    var featuredSection: CommunitySection? {
        didSet {
            updateSections()
        }
    }

    var sections: [CommunitySection] = [] {
        didSet {
            updateSections()
        }
    }

    private func updateSections() {
        if let featured = featuredSection {
            effectiveSections = [featured] + sections
        } else {
            effectiveSections = sections
        }
    }

    private var effectiveSections: [CommunitySection] = [] {
        didSet {
            reloadData()
        }
    }

    private func makeHeaderLayoutItem() -> NSCollectionLayoutBoundarySupplementaryItem {
        let size = NSCollectionLayoutSize(widthDimension: .fractionalWidth(0.95), heightDimension: .absolute(88))

        let item = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: size,
            elementKind: NSCollectionView.elementKindSectionHeader,
            alignment: .topLeading
        )

        item.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 0)

        return item
    }

    private func makeLayout() -> NSCollectionViewLayout {
        NSCollectionViewCompositionalLayout { index, env in
            let isFeaturedSection = self.featuredSection != nil && index == 0

            let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .fractionalHeight(1))

            let layoutItem = NSCollectionLayoutItem(layoutSize: itemSize)
            layoutItem.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: -22, bottom: 0, trailing: 0)
            let layoutGroupSize = NSCollectionLayoutSize(
                widthDimension: isFeaturedSection ? .absolute(588) : .fractionalWidth(0.3),
                heightDimension: isFeaturedSection ? .absolute(207) : .absolute(200)
            )

            let group = NSCollectionLayoutGroup.vertical(layoutSize: layoutGroupSize, subitems: [layoutItem])
            group.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 22, bottom: 0, trailing: 22)

            let section = NSCollectionLayoutSection(group: group)

            section.boundarySupplementaryItems = isFeaturedSection ? [] : [self.makeHeaderLayoutItem()]
            section.orthogonalScrollingBehavior = .continuous
            section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 22, bottom: 22, trailing: 0)

            return section
        }
    }

    private lazy var scrollView: NSScrollView = {
        let v = NSScrollView(frame: view.bounds)

        v.hasHorizontalScroller = false
        v.hasVerticalScroller = false
        v.backgroundColor = .clear
        v.automaticallyAdjustsContentInsets = false
        v.contentInsets = NSEdgeInsets(top: 42, left: 0, bottom: 80, right: 0)
        v.translatesAutoresizingMaskIntoConstraints = false

        return v
    }()

    private lazy var collectionView: NSCollectionView = {
        let v = NSCollectionView()

        v.collectionViewLayout = self.makeLayout()
        v.backgroundColors = [.clear]
        v.dataSource = self
        v.delegate = self

        return v
    }()

    private let disposeBag = DisposeBag()

    override func loadView() {
        view = NSView()
        view.wantsLayer = true

        view.addSubview(scrollView)
        scrollView.documentView = collectionView

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        collectionView.register(CommunityCollectionViewItem.self, forItemWithIdentifier: .communityItem)
        collectionView.register(FeaturedCommunityCollectionViewItem.self, forItemWithIdentifier: .communityFeaturedItem)
        collectionView.register(CommunitySectionHeaderView.self, forSupplementaryViewOfKind: NSCollectionView.elementKindSectionHeader, withIdentifier: .communitySectionHeader)
    }

    private func reloadData() {
        NSObject.cancelPreviousPerformRequests(withTarget: collectionView, selector: #selector(NSCollectionView.reloadData), object: nil)
        collectionView.perform(#selector(NSCollectionView.reloadData), with: nil, afterDelay: 0.1)
    }

}

extension CommunityCollectionViewController: NSCollectionViewDataSource, NSCollectionViewDelegate {

    func numberOfSections(in collectionView: NSCollectionView) -> Int { effectiveSections.count }

    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        effectiveSections[section].items.count
    }

    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let item = effectiveSections[indexPath.section].items[indexPath.item]

        if item.isFeatured {
            return featuredCollectionViewItem(for: item, at: indexPath)
        } else {
            return newsCollectionViewItem(for: item, at: indexPath)
        }
    }

    private func newsCollectionViewItem(for item: CommunityNewsItemViewModel, at indexPath: IndexPath) -> NSCollectionViewItem {
        guard let cell = collectionView.makeItem(withIdentifier: .communityItem, for: indexPath) as? CommunityCollectionViewItem else {
            preconditionFailure("Invalid cell")
        }

        let item = effectiveSections[indexPath.section].items[indexPath.item]
        cell.newsItem = item
        cell.clickHandler = { [weak self] in
            self?.didSelectItem(item)
        }

        return cell
    }

    private func featuredCollectionViewItem(for item: CommunityNewsItemViewModel, at indexPath: IndexPath) -> NSCollectionViewItem {
        guard let cell = collectionView.makeItem(withIdentifier: .communityFeaturedItem, for: indexPath) as? FeaturedCommunityCollectionViewItem else {
            preconditionFailure("Invalid cell")
        }

        let item = effectiveSections[indexPath.section].items[indexPath.item]
        cell.newsItem = item
        cell.clickHandler = { [weak self] in
            self?.didSelectItem(item)
        }

        return cell
    }

    func collectionView(_ collectionView: NSCollectionView, viewForSupplementaryElementOfKind kind: NSCollectionView.SupplementaryElementKind, at indexPath: IndexPath) -> NSView {
        guard let headerView = collectionView.makeSupplementaryView(ofKind: kind, withIdentifier: .communitySectionHeader, for: indexPath) as? CommunitySectionHeaderView else {
            return NSView()
        }

        let section = effectiveSections[indexPath.section]
        headerView.title = section.title
        headerView.color = section.color

        return headerView
    }

}
