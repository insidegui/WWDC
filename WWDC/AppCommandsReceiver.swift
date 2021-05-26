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

    func handle(_ command: WWDCAppCommand, storage: Storage) -> DeepLink? {
        os_log("%{public}@ %@", log: log, type: .debug, #function, String(describing: command))
        
        switch command {
        case .toggleFavorite(let id):
            guard let session = storage.session(with: id) else {
                os_log("Couldn't find session with id %{public}@", log: self.log, type: .error, id)
                return nil
            }
            
            storage.toggleFavorite(on: session)
            
            return nil
        case .toggleWatched(let id):
            guard let session = storage.session(with: id) else {
                os_log("Couldn't find session with id %{public}@", log: self.log, type: .error, id)
                return nil
            }
            
            storage.toggleWatched(on: session)
            
            return nil
        case .download(let id):
            guard let session = storage.session(with: id) else {
                os_log("Couldn't find session with id %{public}@", log: self.log, type: .error, id)
                return nil
            }
            
            DownloadManager.shared.download([session])
            
            return nil
        case .cancelDownload(let id):
            guard let session = storage.session(with: id) else {
                os_log("Couldn't find session with id %{public}@", log: self.log, type: .error, id)
                return nil
            }
            
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
