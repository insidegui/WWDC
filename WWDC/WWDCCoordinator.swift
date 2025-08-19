//
//  WWDCCoordinator.swift
//  WWDC
//
//  Created by luca on 30.07.2025.
//  Copyright © 2025 Guilherme Rambo. All rights reserved.
//

import AppKit
import Combine
import ConfCore
import PlayerUI

@MainActor
protocol WWDCCoordinator: Logging, Signposting, ShelfViewControllerDelegate, PUITimelineDelegate, VideoPlayerViewControllerDelegate, SessionActionsDelegate, RelatedSessionsDelegate, SessionsTableViewControllerDelegate {
    associatedtype TabController: WWDCTabController
    var liveObserver: LiveObserver { get }

    var storage: Storage { get }
    var syncEngine: SyncEngine { get }

    // - Top level controllers
    var windowController: WWDCWindowControllerObject { get }
    var tabController: TabController { get }

    var currentPlayerController: VideoPlayerViewController? { get set }

    var currentActivity: NSUserActivity? { get set }

    var activeTab: MainWindowTab { get }

    /// The tab that "owns" the current player (the one that was active when the "play" button was pressed)
    var playerOwnerTab: MainWindowTab? { get set }

    /// The session that "owns" the current player (the one that was selected on the active tab when "play" was pressed)
    var playerOwnerSessionIdentifier: String? { get set }

    /// Whether we're currently in the middle of a player context transition
    var isTransitioningPlayerContext: Bool { get set }

    /// Whether we were playing the video when a clip sharing session begin, to restore state later.
    var wasPlayingWhenClipSharingBegan: Bool { get set }

    var exploreTabLiveSession: AnyPublisher<SessionViewModel?, Never> { get }

    /// The session that is currently selected on the videos tab (observable)
    var videosSelectedSessionViewModel: SessionViewModel? { get }

    /// The session that is currently selected on the schedule tab (observable)
    var scheduleSelectedSessionViewModel: SessionViewModel? { get }

    /// The selected session's view model, regardless of which tab it is selected in
    var activeTabSelectedSessionViewModel: SessionViewModel? { get }

    /// The viewModel for the current playback session
    var currentPlaybackViewModel: PlaybackViewModel? { get set }

    // MARK: - Shelf

    func select(session: SessionIdentifiable, removingFiltersIfNeeded: Bool)
    func shelf(for tab: MainWindowTab) -> ShelfViewController?
    func showClipUI()

    // MARK: - Related Sessions

    func selectSessionOnAppropriateTab(with viewModel: SessionViewModel)

    // MARK: - App Delegate
    @discardableResult func receiveNotification(with userInfo: [String: Any]) -> Bool
    func handle(link: DeepLink)
    func showPreferences(_ sender: Any?)
    func showAboutWindow()
    func showExplore()
    func showSchedule()
    func showVideos()
    func refresh(_ sender: Any?)
    func applyFilter(state: WWDCFiltersState)
}
