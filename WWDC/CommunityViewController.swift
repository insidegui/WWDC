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
        CommunityCollectionViewController()
    }()

    private let disposeBag = DisposeBag()

    override func loadView() {
        view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.contentBackground.cgColor

        addChild(collectionController)
        collectionController.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(collectionController.view)

        NSLayoutConstraint.activate([
            collectionController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionController.view.topAnchor.constraint(equalTo: view.topAnchor),
            collectionController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        syncEngine.storage.communityNewsItemsObservable
                          .observeOn(MainScheduler.instance)
                          .subscribe(onNext: { [weak self] results in
                              self?.collectionController.newsItems = results
                          })
                          .disposed(by: disposeBag)

        syncEngine.storage.cocoaHubEditionsObservable
                          .observeOn(MainScheduler.instance)
                          .subscribe(onNext: { [weak self] results in
                              self?.collectionController.editions = results
                          })
                          .disposed(by: disposeBag)
    }
    
}
