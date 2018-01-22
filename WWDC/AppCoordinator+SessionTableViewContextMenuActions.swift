//
//  AppCoordinator+SessionTableViewContextMenuActions.swift
//  WWDC
//
//  Created by Soneé John on 6/11/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
import RealmSwift
import RxSwift
import ConfCore
import PlayerUI
import EventKit

extension AppCoordinator: SessionsTableViewControllerDelegate {

    func sessionTableViewContextMenuActionWatch(viewModels: [SessionViewModel]) {
        storage.modify(viewModels.map({ $0.session })) { sessions in
            sessions.forEach { session in
                if let instance = session.instances.first {
                    guard !instance.isCurrentlyLive else { return }

                    guard session.asset(of: .streamingVideo) != nil else {
                        return
                    }
                }

                session.setCurrentPosition(1, 1)
            }
        }
    }

    func sessionTableViewContextMenuActionUnWatch(viewModels: [SessionViewModel]) {
        storage.modify(viewModels.map({ $0.session })) { sessions in
            sessions.forEach { $0.resetProgress() }
        }
    }

    func sessionTableViewContextMenuActionFavorite(viewModels: [SessionViewModel]) {
        storage.modify(viewModels.map({ $0.session })) { sessions in
            sessions.forEach { $0.favorites.append(Favorite()) }
        }
    }

    func sessionTableViewContextMenuActionRemoveFavorite(viewModels: [SessionViewModel]) {
        storage.modify(viewModels.map({ $0.session })) { sessions in
            sessions.forEach { $0.favorites.removeAll() }
        }
    }

    func sessionTableViewContextMenuActionDownload(viewModels: [SessionViewModel]) {
        if viewModels.count > 5 {
            // asking to download many videos, warn
            let alert = WWDCAlert.create()

            alert.messageText = "Download several videos"
            alert.informativeText = "You're about to download \(viewModels.count) videos. This can consume several gigabytes of internet bandwidth and disk space. Are you sure you want to download all \(viewModels.count) videos at once?"

            alert.addButton(withTitle: "No")
            alert.addButton(withTitle: "Yes")

            enum Choice: Int {
                case yes = 1001
                case no = 1000
            }

            guard let choice = Choice(rawValue: alert.runModal().rawValue) else { return }

            guard case .yes = choice else { return }
        }

        viewModels.forEach { viewModel in
            guard let videoAsset = viewModel.session.assets.filter("rawAssetType == %@", SessionAssetType.hdVideo.rawValue).first else { return }

            DownloadManager.shared.download(videoAsset)
        }
    }

    func sessionTableViewContextMenuActionCancelDownload(viewModels: [SessionViewModel]) {
        viewModels.forEach { viewModel in
            guard let videoAsset = viewModel.session.assets.filter("rawAssetType == %@", SessionAssetType.hdVideo.rawValue).first else { return }

            guard DownloadManager.shared.isDownloading(videoAsset.remoteURL) else { return }

            DownloadManager.shared.deleteDownload(for: videoAsset)
        }
    }

    func sessionTableViewContextMenuActionRevealInFinder(viewModels: [SessionViewModel]) {
        guard let firstSession = viewModels.first?.session else { return }
        guard let localURL = DownloadManager.shared.localFileURL(for: firstSession) else { return }

        NSWorkspace.shared.selectFile(localURL.path, inFileViewerRootedAtPath: localURL.deletingLastPathComponent().path)
    }

}
