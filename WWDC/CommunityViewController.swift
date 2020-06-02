//
//  CommunityViewController.swift
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

final class CommunityViewController: NSViewController {

    let syncEngine: SyncEngine

    init(syncEngine: SyncEngine) {
        self.syncEngine = syncEngine

        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    private lazy var collectionController: CommunityCollectionViewController = {
        let c = CommunityCollectionViewController()

        c.didSelectItem = { [weak self] item in
            self?.handleContentSelected(item)
        }

        return c
    }()

    private lazy var centeredLogo: CocoaHubLogoView = {
        let v = CocoaHubLogoView()

        v.translatesAutoresizingMaskIntoConstraints = false

        return v
    }()

    private lazy var cornerLogo: CocoaHubLogoView = {
        let v = CocoaHubLogoView()

        v.translatesAutoresizingMaskIntoConstraints = false

        return v
    }()

    private let disposeBag = DisposeBag()

    override func loadView() {
        view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.contentBackground.cgColor

        addChild(collectionController)
        collectionController.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(collectionController.view)

        view.addSubview(centeredLogo)
        view.addSubview(cornerLogo)

        NSLayoutConstraint.activate([
            collectionController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionController.view.topAnchor.constraint(equalTo: view.topAnchor),
            collectionController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            centeredLogo.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            centeredLogo.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            cornerLogo.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -42),
            cornerLogo.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -32)
        ])

        syncEngine.storage.communityNewsItemsObservable
                          .throttle(.milliseconds(500), scheduler: MainScheduler.instance)
                          .observeOn(MainScheduler.instance)
                          .subscribe(onNext: { [weak self] results in
                            self?.collectionController.sections = CommunitySection.sections(from: results)
                          })
                          .disposed(by: disposeBag)

        syncEngine.storage.featuredCommunityNewsItemsObservable
                          .throttle(.milliseconds(500), scheduler: MainScheduler.instance)
                          .observeOn(MainScheduler.instance)
                          .subscribe(onNext: { [weak self] results in
                            self?.collectionController.featuredSection = CommunitySection.featuredSection(with: results)
                          })
                          .disposed(by: disposeBag)

        let emptyObservable = syncEngine.storage.communityNewsItemsObservable.map { $0.isEmpty }

        emptyObservable.asDriver(onErrorJustReturn: true)
                       .map({ !$0 })
                       .drive(centeredLogo.rx.isHidden)
                       .disposed(by: disposeBag)

        emptyObservable.asDriver(onErrorJustReturn: true)
                       .drive(cornerLogo.rx.isHidden)
                       .disposed(by: disposeBag)
    }

    private func handleContentSelected(_ item: CommunityNewsItemViewModel) {
        if item.url.isAppleDeveloperURL {
            NotificationCenter.default.post(name: .openWWDCURL, object: item.url)
        } else {
            NSWorkspace.shared.open(item.url)
        }
    }
    
}

fileprivate extension CommunitySection {
    static func featuredSection(with items: Results<CommunityNewsItem>) -> CommunitySection {
        CommunitySection(
            tag: CommunityTagViewModel(
                name: "featured",
                title: "Featured",
                order: -1,
                color: .primaryText
            ),
            title: "Featured",
            color: .primaryText,
            items: items.compactMap(CommunityNewsItemViewModel.init)
        )
    }
}

fileprivate extension URL {
    var isAppleDeveloperURL: Bool {
        guard let host = host else { return false }
        return host == DeepLink.Constants.appleHost
    }
}
