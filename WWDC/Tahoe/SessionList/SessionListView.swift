//
//  SessionListView.swift
//  WWDC
//
//  Created by luca on 06.08.2025.
//  Copyright © 2025 Guilherme Rambo. All rights reserved.
//

import Combine
import SwiftUI

@available(macOS 26.0, *)
struct SessionListView: View {
    @Environment(SessionListViewModel.self) var viewModel
    @Environment(\.coordinator) var coordinator

    var body: some View {
        @Bindable var viewModel = viewModel
        List(viewModel.sections, selection: $viewModel.selectedSessions) { section in
            Section {
                ForEach(section.sessions) { session in
                    SessionItemView()
                        .environment(session.model)
                        .id(session)
                }
            } header: {
                Group {
                    if let symbol = section.systemSymbol {
                        Label(section.title, systemImage: symbol)
                            .labelIconToTitleSpacing(5)
                    } else {
                        Text(section.title)
                    }
                }
                .lineLimit(1)
                .font(.headline)
            }
            .listRowInsets(.all, 0)
        }
        .contextMenu(forSelectionType: SessionListSection.Session.self) { items in
            contextMenus(for: items)
        }
        .task {
            viewModel.prepareForDisplay()
        }
    }

    @ViewBuilder
    private func contextMenus(for targetSessions: Set<SessionListSection.Session>) -> some View {
        // model here is pure for making swiftui update this menu, if something changed
        watchedMenus(targetSessions: targetSessions)

        Divider()

        favouritesMenus(targetSessions: targetSessions)

        Divider()

        downloadsMenus(targetSessions: targetSessions)
    }

    @ViewBuilder
    private func watchedMenus(targetSessions: Set<SessionListSection.Session>) -> some View {
        let canMarkAsWatchedSessions = targetSessions.allIfContains {
            let canMarkAsWatched = !$0.model.session.session.isWatched
                && $0.model.session.session.instances.first?.isCurrentlyLive != true
                && $0.model.session.session.asset(ofType: .streamingVideo) != nil
            return canMarkAsWatched
        }
        let watchedTitle = canMarkAsWatchedSessions.count > 1 ? "Mark \(canMarkAsWatchedSessions.count) Sessions as Watched" : "Mark as Watched"
        Button(watchedTitle, systemImage: "rectangle.badge.checkmark") {
            coordinator?.sessionTableViewContextMenuActionWatch(viewModels: canMarkAsWatchedSessions.map(\.model.session))
        }
        .disabled(canMarkAsWatchedSessions.isEmpty)

        let canMarkAsUnWatchedSessions = targetSessions.allIfContains {
            $0.model.session.session.isWatched || $0.model.session.session.progresses.count > 0
        }
        let unwatchedTitle = canMarkAsUnWatchedSessions.count > 1 ? "Mark \(canMarkAsUnWatchedSessions.count) Sessions as Unwatched" : "Mark as Unwatched"
        Button(unwatchedTitle, systemImage: "rectangle.badge.minus") {
            coordinator?.sessionTableViewContextMenuActionUnWatch(viewModels: canMarkAsUnWatchedSessions.map(\.model.session))
        }
        .disabled(canMarkAsUnWatchedSessions.isEmpty)
    }

    @ViewBuilder
    private func favouritesMenus(targetSessions: Set<SessionListSection.Session>) -> some View {
        let canMarkFavouriteSessions = targetSessions.allIfContains {
            !$0.model.isFavorite
        }
        let addToFavouritesTitle = canMarkFavouriteSessions.count > 1 ? "Add \(canMarkFavouriteSessions.count) Sessions to Favorites" : "Add to Favorites"
        Button(addToFavouritesTitle, systemImage: "star") {
            coordinator?.sessionTableViewContextMenuActionFavorite(viewModels: canMarkFavouriteSessions.map(\.model.session))
        }
        .disabled(canMarkFavouriteSessions.isEmpty)

        let canRemoveFavouriteSessions = targetSessions.allIfContains {
            $0.model.isFavorite
        }
        let removeFormFavouritesTitle = canRemoveFavouriteSessions.count > 1 ? "Remove \(canRemoveFavouriteSessions.count) Sessions from Favorites" : "Remove from Favorites"
        Button(removeFormFavouritesTitle, systemImage: "star.slash") {
            coordinator?.sessionTableViewContextMenuActionRemoveFavorite(viewModels: canRemoveFavouriteSessions.map(\.model.session))
        }
        .disabled(canRemoveFavouriteSessions.isEmpty)
    }

    @ViewBuilder
    private func downloadsMenus(targetSessions: Set<SessionListSection.Session>) -> some View {
        let downloadableSessions = targetSessions.filter { MediaDownloadManager.shared.canDownloadMedia(for: $0.model.session.session) &&
            !MediaDownloadManager.shared.isDownloadingMedia(for: $0.model.session.session) &&
            !MediaDownloadManager.shared.hasDownloadedMedia(for: $0.model.session.session)
        }
        let downloadTitle = downloadableSessions.count > 1 ? "Download \(downloadableSessions.count) Sessions" : "Download"
        Button(downloadTitle, systemImage: "arrow.down.document") {
            coordinator?.sessionTableViewContextMenuActionDownload(viewModels: downloadableSessions.map(\.model.session))
        }
        .disabled(downloadableSessions.isEmpty)

        let removableSessions = targetSessions.filter { $0.model.session.session.isDownloaded
        }
        let removeDownloadTitle = removableSessions.count > 1 ? "Remove Download of \(removableSessions.count) Sessions" : "Remove Download"
        Button(removeDownloadTitle, systemImage: "trash") {
            coordinator?.sessionTableViewContextMenuActionRemoveDownload(viewModels: removableSessions.map(\.model.session))
        }
        .disabled(removableSessions.isEmpty)

        let cancellableSessions = targetSessions.filter { MediaDownloadManager.shared.canDownloadMedia(for: $0.model.session.session) && MediaDownloadManager.shared.isDownloadingMedia(for: $0.model.session.session)
        }
        let cancelDownloadTitle = cancellableSessions.count > 1 ? "Cancel Download of \(cancellableSessions.count) Sessions" : "Cancel Download"
        Button(cancelDownloadTitle, systemImage: "arrow.down.circle.badge.xmark") {
            coordinator?.sessionTableViewContextMenuActionCancelDownload(viewModels: cancellableSessions.map(\.model.session))
        }
        .disabled(cancellableSessions.isEmpty)

        let downloadedSessions = targetSessions.filter { MediaDownloadManager.shared.hasDownloadedMedia(for: $0.model.session.session)
        }
        let revealInFinderTitle = downloadedSessions.count > 1 ? "Show \(downloadedSessions.count) Sessions in Finder" : "Show in Finder" // Similar to Xcode
        Button(revealInFinderTitle, systemImage: "finder") {
            coordinator?.sessionTableViewContextMenuActionRevealInFinder(viewModels: downloadedSessions.map(\.model.session))
        }
        .disabled(downloadedSessions.isEmpty)
    }
}

private extension Collection where Element == SessionListSection.Session {
    func allIfContains(where isIncluded: (_ element: Element) -> Bool) -> [Element] {
        if contains(where: isIncluded) {
            return Array(self)
        } else {
            return []
        }
    }
}
