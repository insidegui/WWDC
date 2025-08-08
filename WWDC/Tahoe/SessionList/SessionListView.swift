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

    var body: some View {
        @Bindable var viewModel = viewModel
        List(viewModel.sections, selection: $viewModel.selectedSessions) { section in
            Section {
                ForEach(section.sessions) { session in
                    SessionItemView()
                        .environment(session.model)
                        .id(session)
                        .contextMenu { contextMenus(for: session.model) }
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
        .task {
            viewModel.prepareForDisplay()
        }
    }

    @ViewBuilder
    private func contextMenus(for session: SessionItemViewModel) -> some View {
        watchedMenus(for: session)

        Divider()

        favouritesMenus(for: session)

        Divider()

        downloadsMenus(for: session)
    }

    @ViewBuilder
    private func watchedMenus(for session: SessionItemViewModel) -> some View {
        let watchedTitle = viewModel.selectedSessions.count > 1 ? "Mark \(viewModel.selectedSessions.count) Sessions as Watched" : "Mark as Watched"
        Button(watchedTitle, systemImage: "rectangle.badge.checkmark") {}

        let unwatchedTitle = viewModel.selectedSessions.count > 1 ? "Mark \(viewModel.selectedSessions.count) Sessions as Unwatched" : "Mark as Unwatched"
        Button(unwatchedTitle, systemImage: "rectangle.badge.minus") {}
    }

    @ViewBuilder
    private func favouritesMenus(for session: SessionItemViewModel) -> some View {
        let addToFavouritesTitle = viewModel.selectedSessions.count > 1 ? "Add \(viewModel.selectedSessions.count) Sessions to Favorites" : "Add to Favorites"
        Button(addToFavouritesTitle, systemImage: "star") {}

        let removeFormFavouritesTitle = viewModel.selectedSessions.count > 1 ? "Remove \(viewModel.selectedSessions.count) Sessions from Favorites" : "Remove from Favorites"
        Button(removeFormFavouritesTitle, systemImage: "star.slash") {}
    }

    @ViewBuilder
    private func downloadsMenus(for session: SessionItemViewModel) -> some View {
        let downloadedSessions = viewModel.selectedSessions.filter({ $0.model.isDownloaded })
        let downloadSessions = viewModel.selectedSessions.filter({ !$0.model.isDownloaded })
        let downloadTitle = downloadSessions.count > 1 ? "Download \(downloadSessions.count) Sessions" : "Download"
        Button(downloadTitle, systemImage: "arrow.down.document") {}
            .disabled(downloadSessions.isEmpty)

        let removeDownloadTitle = downloadedSessions.count > 1 ? "Remove Download of \(downloadedSessions.count) Sessions" : "Remove Download"
        Button(removeDownloadTitle, systemImage: "trash") {}
            .disabled(downloadedSessions.isEmpty)

//        let downloadingSessions = viewModel.selectedSessions.filter({
//            switch $0.model.actionsViewModel.downloadState {
//            case .pending, .downloading:
//                return true
//            case .notDownloadable, .downloaded, .downloadable:
//                return false
//            }
//        })
//        let cancelDownloadTitle = downloadingSessions.count > 1 ? "Cancel Download of \(downloadingSessions.count) Sessions" : "Cancel Download"
//        Button(cancelDownloadTitle, systemImage: "arrow.down.circle.badge.xmark") {}
//            .disabled(downloadingSessions.isEmpty)

        let revealInFinderTitle = downloadedSessions.count > 1 ? "Cancel Download of \(downloadedSessions.count) Sessions" : "Cancel Download"
        Button(revealInFinderTitle, systemImage: "arrow.down.circle.badge.xmark") {}
            .disabled(downloadedSessions.isEmpty)
    }
}
