//
//  SessionActionsView.swift
//  WWDC
//
//  Created by Allen Humphreys on 7/17/25.
//  Copyright © 2025 Guilherme Rambo. All rights reserved.
//

import PlayerUI
import SwiftUI

struct SessionActionsView: View {
    @ObservedObject var viewModel: SessionActionsViewModel
    var alignment = Alignment.leading

    var body: some View {
        HStack(spacing: 0) {
            PUIButtonView(.alwaysHighlighted(image: .slides)) {
                viewModel.showSlides()
            }
            .help("Open slides")
            .opacity(viewModel.slidesButtonIsHidden ? 0 : 1)
            .frame(width: viewModel.slidesButtonIsHidden ? 0 : nil, alignment: .trailing)

            PUIButtonView(
                .init(
                    alwaysHighlighted: true,
                    isToggle: true,
                    image: .favorite,
                    alternateImage: .favoriteFilled,
                    state: viewModel.isFavorited ? .on : .off
                )
            ) {
                viewModel.toggleFavorite()
            }
            .help(viewModel.isFavorited ? "Remove from favorites" : "Add to favorites")
            .padding(.leading, 22)

            downloadButton

            PUIButtonView(.alwaysHighlighted(image: .share)) {
                viewModel.share()
            }
            .help("Share session")
            .padding(.leading, 22)

            PUIButtonView(.alwaysHighlighted(image: .clip)) {
                viewModel.shareClip()
            }
            .padding(.leading, 22)
            .help("Share a Clip")
            .opacity(viewModel.downloadState == .downloaded ? 1 : 0)
            .frame(width: viewModel.downloadState == .downloaded ? nil : 0, alignment: .leading)

            PUIButtonView(.alwaysHighlighted(image: .calendar)) {
                viewModel.addCalendar()
            }
            .padding(.leading, 22)
            .help("Add to Calendar")
            .opacity(viewModel.calendarButtonIsHidden ? 0 : 1)
            .frame(width: viewModel.calendarButtonIsHidden ? 0 : nil, alignment: .trailing)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
    }

    /// States managed by DownloadState enum:
    /// - .notDownloadable: no button, no progress (allocatesSpace: false)
    /// - .downloadable: shows download button (showsButton: true, help: "Download video for offline watching")
    /// - .pending: shows progress indicator without percentage (showsButton: false, help: "Preparing download")
    /// - .downloading(progress): shows progress indicator with percentage (showsButton: false, help: "Downloading: X%")
    /// - .downloaded: shows delete button (showsButton: true, help: "Delete downloaded video")
    var downloadButton: some View {
        PUIButtonView(.alwaysHighlighted(image: viewModel.downloadState == .downloaded ? .trash : .download)) {
            if viewModel.downloadState == .downloaded {
                viewModel.deleteDownload()
            } else {
                viewModel.download()
            }
        }
        .opacity(viewModel.downloadState.showsButton ? 1 : 0)
        .overlay {
            if viewModel.downloadState.isDownloading || viewModel.downloadState.isPending {
                WWDCProgressIndicator(
                    value: viewModel.downloadState.downloadProgress,
                    action: viewModel.cancelDownload
                )
            }
        }
        .help(downloadButtonHelp)
        .padding(.leading, 22)
        .frame(width: viewModel.downloadState.allocatesSpace ? nil : 0, alignment: .trailing)
    }

    var downloadButtonHelp: String {
        switch viewModel.downloadState {
        case .downloaded:
            "Delete downloaded video"
        case .downloadable:
            "Download video for offline watching"
        case .downloading(let progress):
            "Downloading: \(progress.formatted(.percent.precision(.fractionLength(0))))"
        case .pending:
            "Preparing download"
        case .notDownloadable:
            ""
        }
    }
}

#Preview {
    SessionActionsView(viewModel: SessionActionsViewModel(session: .preview))
        .padding()
}
