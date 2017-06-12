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

extension AppCoordinator: SessionsTableViewControllerDelegate  {
    
    func sessionTableViewContextMenuActionWatch(viewModels: [SessionViewModel]) {
        
        for viewModel in viewModels {
        
            if viewModel.sessionInstance.isCurrentlyLive {
               continue
            } else {
                viewModel.session.setCurrentPosition(1, 1)
            }
        }
    
    }
    
    func sessionTableViewContextMenuActionUnWatch(viewModels: [SessionViewModel]) {
        
        for viewModel in viewModels {
            
            viewModel.session.resetProgress()
        }
    }
    
    func sessionTableViewContextMenuActionFavorite(viewModels: [SessionViewModel]) {
    
        for viewModel in viewModels {
            
            if !viewModel.isFavorite {
                storage.createFavorite(for: viewModel.session)
            }
        }
    }
    
    func sessionTableViewContextMenuActionRemoveFavorite(viewModels: [SessionViewModel]) {
        
        for viewModel in viewModels {
            
            if viewModel.isFavorite {
                storage.removeFavorite(for: viewModel.session)
            }
        }
    }
    
    func sessionTableViewContextMenuActionDownload(viewModels: [SessionViewModel]) {
        
        for viewModel in viewModels {
            
            guard let videoAsset = viewModel.session.assets.filter({ $0.assetType == .hdVideo }).first else { continue }
            
            DownloadManager.shared.download(videoAsset)
        }
    }
    
    func sessionTableViewContextMenuActionCancelDownload(viewModels: [SessionViewModel]) {
        
        for viewModel in viewModels {
        
            if let videoAsset = viewModel.session.assets.filter({ $0.assetType == .hdVideo }).first {
                if !DownloadManager.shared.isDownloading(videoAsset.remoteURL) {
                    continue
                }
                
                DownloadManager.shared.deleteDownload(for: videoAsset)
            }
        }
    }
}

