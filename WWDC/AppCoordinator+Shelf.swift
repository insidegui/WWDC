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

    private func shelf(for tab: MainWindowTab?) -> ShelfViewController? {
        guard let tab = tab else { return nil }

        var shelfViewController: ShelfViewController?
        switch tab {
        case .schedule:
            shelfViewController = scheduleController.detailViewController.shelfController
        case .videos:
            shelfViewController = videosController.detailViewController.shelfController
        default: ()
        }

        return shelfViewController
    }

    func updateShelfBasedOnSelectionChange() {
        guard !isTransitioningPlayerContext else { return }

        guard currentPlaybackViewModel != nil else { return }
        guard let playerController = currentPlayerController else { return }

        shelf(for: playerOwnerTab)?.playerContainer.animator().isHidden = playerOwnerSessionIdentifier != selectedViewModelRegardlessOfTab?.identifier

        // Everything after this point is for automatically entering PiP

        // ignore when not playing or when playing externally
        guard playerController.playerView.isInternalPlayerPlaying else { return }

        // ignore when playing in fullscreen
        guard !playerController.playerView.isInFullScreenPlayerWindow else { return }

        // if the user selected a different session/tab during playback, we move the player to PiP mode and hide the player on the shelf

        if !playerController.playerView.isInPictureInPictureMode {
            playerController.playerView.togglePip(nil)
        }
    }

    func returnToPlayingSessionContext() {
        isTransitioningPlayerContext = true
        defer { isTransitioningPlayerContext = false }

        guard playerOwnerSessionIdentifier != selectedViewModelRegardlessOfTab?.identifier else { return }
        guard let identifier = playerOwnerSessionIdentifier else { return }
        guard let tab = playerOwnerTab else { return }

        tabController.activeTab = tab
        currentListController?.select(session: SessionIdentifier(identifier))

        shelf(for: playerOwnerTab)?.playerContainer.animator().isHidden = false
    }

    func shelfViewControllerDidSelectPlay(_ shelfController: ShelfViewController) {

        currentPlaybackViewModel = nil

        guard let viewModel = shelfController.viewModel else { return }

        playerOwnerTab = activeTab
        playerOwnerSessionIdentifier = selectedViewModelRegardlessOfTab?.identifier

        do {
            let playbackViewModel = try PlaybackViewModel(sessionViewModel: viewModel, storage: storage)
            playbackViewModel.image = shelfController.shelfView.image

            isTransitioningPlayerContext = false

            currentPlaybackViewModel = playbackViewModel

            if currentPlayerController == nil {
                currentPlayerController = VideoPlayerViewController(player: playbackViewModel.player, session: viewModel)
                currentPlayerController?.playerWillExitPictureInPicture = { [weak self] reason in
                    guard reason == .returnButton else { return }
                    self?.returnToPlayingSessionContext()
                }

                currentPlayerController?.playerWillExitFullScreen = { [weak self] in
                    self?.returnToPlayingSessionContext()
                }

                currentPlayerController?.delegate = self
                currentPlayerController?.playerView.timelineDelegate = self

                attachPlayerToShelf(shelfController)
            } else {
                currentPlayerController?.player = playbackViewModel.player
                currentPlayerController?.sessionViewModel = viewModel
            }

            currentPlayerController?.playbackViewModel = playbackViewModel

        } catch {
            WWDCAlert.show(with: error)
        }
    }

    private var playerTouchBarContainer: MainWindowController? {
        return currentPlayerController?.view.window?.windowController as? MainWindowController
    }

    private func attachPlayerToShelf(_ shelf: ShelfViewController) {
        guard let playerController = currentPlayerController else { return }

        shelf.playButton.isHidden = true

        let playerContainer = shelf.playerContainer
        playerContainer.isHidden = false

        // Already attached
        guard playerController.view.superview != playerContainer else { return }

        playerController.view.frame = playerContainer.bounds
        playerController.view.alphaValue = 0
        playerController.view.isHidden = false

        playerController.view.translatesAutoresizingMaskIntoConstraints = false

        playerContainer.addSubview(playerController.view)
        playerContainer.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "|-(0)-[playerView]-(0)-|", options: [], metrics: nil, views: ["playerView": playerController.view]))

        playerContainer.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|-(0)-[playerView]-(0)-|", options: [], metrics: nil, views: ["playerView": playerController.view]))

        playerController.view.alphaValue = 1

        playerTouchBarContainer?.activePlayerView = playerController.playerView
    }

    func publishNowPlayingInfo() {
        currentPlayerController?.playerView.nowPlayingInfo = currentPlaybackViewModel?.nowPlayingInfo.value
    }

}
