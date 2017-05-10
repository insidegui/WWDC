//
//  AppCoordinator+Shelf.swift
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

extension AppCoordinator: ShelfViewControllerDelegate {
    
    func shelfViewControllerDidSelectPlay(_ controller: ShelfViewController) {
        guard let viewModel = controller.viewModel.value else { return }
        
        do {
            let playbackViewModel = try PlaybackViewModel(sessionViewModel: viewModel, storage: storage)
            
            teardownPlayerIfNeeded()
            
            currentPlayerController = VideoPlayerViewController(player: playbackViewModel.player)
            
            attachPlayerToShelf(controller)
        } catch {
            WWDCAlert.show(with: error)
        }
    }
    
    private func teardownPlayerIfNeeded() {
        guard let playerController = currentPlayerController else { return }
        
        playerController.player.pause()
        playerController.player.cancelPendingPrerolls()
        
        // close detached window
        if let window = playerController.view.window {
            if window != windowController.window {
                window.close()
            }
        }
        
        playerController.view.removeFromSuperview()
        
        currentPlayerController = nil
    }
    
    private func attachPlayerToShelf(_ shelf: ShelfViewController) {
        guard let playerController = currentPlayerController else { return }
        
        shelf.addChildViewController(playerController)
        
        playerController.view.frame = shelf.view.bounds
        playerController.view.alphaValue = 0
        playerController.view.translatesAutoresizingMaskIntoConstraints = false
        
        shelf.view.addSubview(playerController.view)
        
        shelf.view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "|-(0)-[playerView]-(0)-|", options: [], metrics: nil, views: ["playerView": playerController.view]))
        shelf.view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|-(0)-[playerView]-(0)-|", options: [], metrics: nil, views: ["playerView": playerController.view]))
        
        playerController.view.alphaValue = 1
    }
    
}
