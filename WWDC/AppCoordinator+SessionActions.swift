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
        guard let viewModel = selectedSessionValue ?? selectedScheduleItemValue else { return }
        
        if viewModel.isFavorite {
            storage.removeFavorite(for: viewModel.session)
        } else {
            storage.createFavorite(for: viewModel.session)
        }
    }
    
    func sessionActionsDidSelectDownload(_ sender: NSView?) {
        guard let viewModel = selectedSessionValue ?? selectedScheduleItemValue else { return }
        
        guard let videoAsset = viewModel.session.assets.filter({ $0.assetType == .hdVideo }).first else { return }
        
        downloadManager.download(videoAsset)
    }
    
    func sessionActionsDidSelectShare(_ sender: NSView?) {
        
    }
    
}
