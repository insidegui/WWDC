//
//  AppCommandsReceiver.swift
//  WWDC
//
//  Created by Guilherme Rambo on 26/05/21.
//  Copyright © 2021 Guilherme Rambo. All rights reserved.
//

import Cocoa
import ConfCore
import os.log

final class AppCommandsReceiver {
    private let log = OSLog(subsystem: "io.wwdc.app", category: String(describing: AppCommandsReceiver.self))

    // swiftlint:disable:next cyclomatic_complexity
    func handle(_ command: WWDCAppCommand, storage: Storage) -> DeepLink? {
        os_log("%{public}@ %@", log: log, type: .debug, #function, String(describing: command))

        switch command {
        case .favorite(let id):
            storage.setFavorite(true, onSessionsWithIDs: [id])
            
            return nil
        case .unfavorite(let id):
            storage.setFavorite(false, onSessionsWithIDs: [id])
            
            return nil
        case .watch:
            guard let session = command.session(in: storage) else { return nil }
            
            storage.setWatched(true, on: session)
            
            return nil
        case .unwatch:
            guard let session = command.session(in: storage) else { return nil }
            
            storage.setWatched(false, on: session)
            
            return nil
        case .download:
            guard let session = command.session(in: storage) else { return nil }
            
            DownloadManager.shared.download([session])
            
            return nil
        case .cancelDownload:
            guard let session = command.session(in: storage) else { return nil }
            
            DownloadManager.shared.cancelDownloads([session])
            
            return nil
        case .revealVideo:
            guard let link = DeepLink(from: command) else {
                os_log("Failed to construct deep link from command: %{public}@", log: self.log, type: .error, String(describing: command))
                return nil
            }
            
            return link
        case .launchPreferences:
            NSApp.sendAction(#selector(AppDelegate.showPreferences(_:)), to: nil, from: nil)
            
            return nil
        }
    }
}

extension WWDCAppCommand {
    var sessionId: String? {
        switch self {
        case .favorite(let id):
            return id
        case .unfavorite(let id):
            return id
        case .watch(let id):
            return id
        case .unwatch(let id):
            return id
        case .download(let id):
            return id
        case .cancelDownload(let id):
            return id
        case .revealVideo(let id):
            return id
        case .launchPreferences:
            return nil
        }
    }
    
    func session(in storage: Storage) -> Session? {
        guard let id = sessionId else { return nil }
        return storage.session(with: id)
    }
}
