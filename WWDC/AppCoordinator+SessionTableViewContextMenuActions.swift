//
//  AppCoordinator+SessionTableViewContextMenuActions.swift
//  WWDC
//
//  Created by Soneé John on 6/11/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
import RealmSwift
import ConfCore
import PlayerUI

extension AppCoordinator: SessionsTableViewControllerDelegate {

    func sessionTableViewContextMenuActionWatch(viewModels: [SessionViewModel]) {
        storage.modify(viewModels.map(\.session)) { @Sendable sessions in
            sessions.forEach { session in
                Storage.setWatched(true, on: session)
            }
        }
    }

    func sessionTableViewContextMenuActionUnWatch(viewModels: [SessionViewModel]) {
        storage.modify(viewModels.map(\.session)) { @Sendable sessions in
            sessions.forEach { Storage.setWatched(false, on: $0) }
        }
    }

    func sessionTableViewContextMenuActionFavorite(viewModels: [SessionViewModel]) {
        storage.setFavorite(true, onSessionsWithIDs: viewModels.map(\.session.identifier))
    }

    func sessionTableViewContextMenuActionRemoveFavorite(viewModels: [SessionViewModel]) {
        storage.setFavorite(false, onSessionsWithIDs: viewModels.map(\.session.identifier))
    }

    @MainActor
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

        MediaDownloadManager.shared.download(viewModels.map(\.session))
    }

    @MainActor
    func sessionTableViewContextMenuActionCancelDownload(viewModels: [SessionViewModel]) {
        let cancellableDownloads = viewModels.map(\.session).filter { MediaDownloadManager.shared.isDownloadingMedia(for: $0) }
        
        MediaDownloadManager.shared.cancelDownload(for: cancellableDownloads)
    }

    @MainActor
    func sessionTableViewContextMenuActionRemoveDownload(viewModels: [SessionViewModel]) {
        let deletableDownloads = viewModels.map(\.session).filter { MediaDownloadManager.shared.hasDownloadedMedia(for: $0) }

        MediaDownloadManager.shared.delete(deletableDownloads)
    }

    @MainActor
    func sessionTableViewContextMenuActionRevealInFinder(viewModels: [SessionViewModel]) {
        guard let firstSession = viewModels.first?.session else { return }
        guard let localURL = MediaDownloadManager.shared.downloadedFileURL(for: firstSession) else { return }

        NSWorkspace.shared.selectFile(localURL.path, inFileViewerRootedAtPath: localURL.deletingLastPathComponent().path)
    }

}

extension Storage {
    static func setWatched(_ watched: Bool, on session: Session) {
        if let instance = session.instances.first {
            guard !instance.isCurrentlyLive else { return }

            guard session.asset(ofType: .streamingVideo) != nil else {
                return
            }
        }

        if watched {
            session.setCurrentPosition(1, 1)
        } else {
            session.resetProgress()
        }
    }
    
    static func toggleWatched(on session: Session) {
        setWatched(!session.isWatched, on: session)
    }
}
