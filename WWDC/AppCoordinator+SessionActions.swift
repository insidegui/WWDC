//
//  AppCoordinator+SessionActions.swift
//  WWDC
//
//  Created by Guilherme Rambo on 06/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
import RealmSwift
import RxSwift
import ConfCore
import PlayerUI

extension AppCoordinator: SessionActionsViewControllerDelegate {
    
    func sessionActionsDidSelectFavorite(_ sender: NSView?) {
        guard let viewModel = selectedViewModelRegardlessOfTab else { return }
        
        if viewModel.isFavorite {
            storage.removeFavorite(for: viewModel.session)
        } else {
            storage.createFavorite(for: viewModel.session)
        }
    }
    
    func sessionActionsDidSelectDownload(_ sender: NSView?) {
        guard let viewModel = selectedViewModelRegardlessOfTab else { return }
        
        guard let videoAsset = viewModel.session.assets.filter({ $0.assetType == .hdVideo }).first else { return }
        
        downloadManager.download(videoAsset)
    }
    
    func sessionActionsDidSelectDeleteDownload(_ sender: NSView?) {        
        guard let viewModel = selectedViewModelRegardlessOfTab else { return }
        
        guard let videoAsset = viewModel.session.assets.filter({ $0.assetType == .hdVideo }).first else { return }
        
        let alert = WWDCAlert.create()
        
        alert.messageText = "Remove downloaded video"
        alert.informativeText = "Are you sure you want to delete the downloaded video? This action can't be undone."
        
        alert.addButton(withTitle: "No")
        alert.addButton(withTitle: "Yes")
        
        enum Choice: Int {
            case yes = 1001
            case no = 1000
        }
        
        guard let choice = Choice(rawValue: alert.runModal()) else { return }
        
        switch choice {
        case .yes:
            self.downloadManager.deleteDownload(for: videoAsset)
        case .no:
            break
        }
    }
    
    func sessionActionsDidSelectShare(_ sender: NSView?) {
        guard let sender = sender else { return }
        guard let viewModel = selectedViewModelRegardlessOfTab else { return }
        
        guard let webpageAsset = viewModel.session.assets.filter({ $0.assetType == .webpage }).first else { return }
        
        guard let url = URL(string: webpageAsset.remoteURL) else { return }
        
        let picker = NSSharingServicePicker(items: [url])
        picker.show(relativeTo: .zero, of: sender, preferredEdge: .minY)
    }
    
}
