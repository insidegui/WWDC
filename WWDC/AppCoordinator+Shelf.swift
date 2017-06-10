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

    func updateShelfBasedOnSelectionChange() {
        guard !isTransitioningPlayerContext else { return }

        guard currentPlaybackViewModel != nil else { return }
        guard let playerController = currentPlayerController else { return }

        guard playerOwnerSessionIdentifier != selectedViewModelRegardlessOfTab?.identifier else {
            playerController.view.isHidden = false
            return
        }

        playerController.view.isHidden = true

        // ignore when not playing or when playing externally
        guard playerController.playerView.isInternalPlayerPlaying else { return }

        // ignore when playing in fullscreen
        guard !playerController.playerView.isInFullScreenPlayerWindow else { return }

        guard !canRestorePlaybackContext else { return }

        // if the user selected a different session/tab during playback, we move the player to PiP mode and hide the player on the shelf

        if !playerController.playerView.isInPictureInPictureMode {
            playerController.playerView.togglePip(nil)
        }

        canRestorePlaybackContext = true
    }

    func goBackToContextBeforePiP() {
        isTransitioningPlayerContext = true
        defer { isTransitioningPlayerContext = false }

        guard canRestorePlaybackContext else { return }
        guard playerOwnerSessionIdentifier != selectedViewModelRegardlessOfTab?.identifier else { return }
        guard let identifier = playerOwnerSessionIdentifier else { return }
        guard let tab = playerOwnerTab else { return }

        tabController.activeTab = tab
        currentListController.selectSession(with: identifier)

        canRestorePlaybackContext = false
        currentPlayerController?.view.isHidden = false
    }

    func shelfViewControllerDidSelectPlay(_ shelfController: ShelfViewController) {
        if let playerController = currentPlayerController {
            if playerController.playerView.isInFullScreenPlayerWindow {
                // close video playing in fullscreen
                playerController.detachedWindowController.close()
            }
        }

        self.currentPlaybackViewModel = nil

        guard let viewModel = shelfController.viewModel else { return }

        self.playerOwnerTab = activeTab
        self.playerOwnerSessionIdentifier = selectedViewModelRegardlessOfTab?.identifier

        do {
            let playbackViewModel = try PlaybackViewModel(sessionViewModel: viewModel, storage: storage)

            canRestorePlaybackContext = false
            isTransitioningPlayerContext = false

            self.currentPlaybackViewModel = playbackViewModel

            if currentPlayerController == nil {
                currentPlayerController = VideoPlayerViewController(player: playbackViewModel.player, session: viewModel)
                currentPlayerController?.playerWillExitPictureInPicture = { [weak self] in
                    self?.goBackToContextBeforePiP()
                }

                currentPlayerController?.delegate = self
                currentPlayerController?.playerView.timelineDelegate = self
            } else {
                currentPlayerController?.player = playbackViewModel.player
                currentPlayerController?.sessionViewModel = viewModel
            }

            currentPlayerController?.playbackViewModel = playbackViewModel

            attachPlayerToShelf(shelfController)
        } catch {
            WWDCAlert.show(with: error)
        }
    }

    private func attachPlayerToShelf(_ shelf: ShelfViewController) {
        guard let playerController = currentPlayerController else { return }

        shelf.playButton.isHidden = true

        playerController.view.frame = shelf.view.bounds
        playerController.view.alphaValue = 0
        playerController.view.isHidden = false

        playerController.view.translatesAutoresizingMaskIntoConstraints = false

        shelf.view.addSubview(playerController.view)
        shelf.view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "|-(0)-[playerView]-(0)-|", options: [], metrics: nil, views: ["playerView": playerController.view]))

        shelf.view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|-(0)-[playerView]-(0)-|", options: [], metrics: nil, views: ["playerView": playerController.view]))

        playerController.view.alphaValue = 1
    }

}
