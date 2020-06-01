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

    var sections: [CommunitySection] = [] {
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

        item.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 30, bottom: 0, trailing: 0)

        return item
    }

    private func makeLayout() -> NSCollectionViewLayout {
        NSCollectionViewCompositionalLayout { index, env in
            let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .fractionalHeight(1))

            let layoutItem = NSCollectionLayoutItem(layoutSize: itemSize)

            let layoutGroupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(0.3), heightDimension: .absolute(200))

            let group = NSCollectionLayoutGroup.vertical(layoutSize: layoutGroupSize, subitem: layoutItem, count: 1)
            group.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 22, bottom: 0, trailing: 0)

            let section = NSCollectionLayoutSection(group: group)

            section.boundarySupplementaryItems = [self.makeHeaderLayoutItem()]
            section.orthogonalScrollingBehavior = .continuous
            section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 22, trailing: 0)

            return section
        }
    }

    private lazy var scrollView: NSScrollView = {
        let v = NSScrollView(frame: view.bounds)

        v.hasHorizontalScroller = false
        v.hasVerticalScroller = false
        v.backgroundColor = .clear
        v.automaticallyAdjustsContentInsets = false
        v.contentInsets = NSEdgeInsets(top: 0, left: 0, bottom: 80, right: 0)

        return v
    }()

    private lazy var collectionView: NSCollectionView = {
        let v = NSCollectionView()

        v.translatesAutoresizingMaskIntoConstraints = false
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

        scrollView.frame = view.bounds
        scrollView.autoresizingMask = [.width, .height]
        view.addSubview(scrollView)
        scrollView.documentView = collectionView

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
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

    func numberOfSections(in collectionView: NSCollectionView) -> Int { sections.count }

    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        sections[section].items.count
    }

    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        guard let cell = collectionView.makeItem(withIdentifier: .communityItem, for: indexPath) as? CommunityCollectionViewItem else {
            preconditionFailure("Invalid cell")
        }

        cell.newsItem = sections[indexPath.section].items[indexPath.item]

        return cell
    }

    func collectionView(_ collectionView: NSCollectionView, viewForSupplementaryElementOfKind kind: NSCollectionView.SupplementaryElementKind, at indexPath: IndexPath) -> NSView {
        guard let headerView = collectionView.makeSupplementaryView(ofKind: kind, withIdentifier: .communitySectionHeader, for: indexPath) as? CommunitySectionHeaderView else {
            return NSView()
        }

        let section = sections[indexPath.section]
        headerView.title = section.title
        headerView.color = section.color

        return headerView
    }

}
