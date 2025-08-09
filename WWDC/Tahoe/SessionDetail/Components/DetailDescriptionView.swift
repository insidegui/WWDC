//
//  DetailDescriptionView.swift
//  WWDC
//
//  Created by luca on 05.08.2025.
//  Copyright © 2025 Guilherme Rambo. All rights reserved.
//

import Combine
import SwiftUI

@available(macOS 26.0, *)
extension NewSessionDetailView {
    struct SessionDescriptionView: View {
        @Environment(SessionItemViewModel.self) var viewModel
        @Binding var tab: SessionDetailsViewModel.SessionTab
        let scrollPosition: Binding<ScrollPosition>

        var body: some View {
            Group {
                switch tab {
                case .overview:
                    if #available(macOS 26.0, *) {
                        OverviewContentView()
                        @Bindable var viewModel = viewModel
                        RelatedSessionsView(sessions: $viewModel.relatedSessions, scrollPosition: scrollPosition)
                    }
                case .transcript:
                    if #available(macOS 26.0, *) {
                        NewTranscriptView(viewModel: viewModel.session, scrollPosition: scrollPosition)
                    }
                case .bookmarks:
                    Text("Bookmarks view coming soon")
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

@available(macOS 26.0, *)
private struct OverviewContentView: View {
    @Environment(SessionItemViewModel.self) var viewModel

    @Environment(\.coordinator) private var appCoordinator
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                Text(viewModel.title)
                    .font(.init(NSFont.boldTitleFont))
                    .foregroundStyle(.primary)
                    .kerning(-0.5)
                    .textSelection(.enabled)
                    .transition(.blurReplace)
                Spacer()
                NewSessionActionsView()
            }
            Text(viewModel.summary)
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .lineHeight(.multiple(factor: 1.2))
                .textSelection(.enabled)
                .transition(.blurReplace)
            Text(viewModel.footer)
                .font(.system(size: 16))
                .foregroundStyle(.tertiary)
                .allowsTightening(true)
                .truncationMode(.tail)
                .textSelection(.enabled)
                .transition(.blurReplace)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding([.bottom, .horizontal])
        .padding(.top, 8) // incase tabs are hidden
        .animation(.bouncy, value: viewModel.title)
        .animation(.bouncy, value: viewModel.summary)
        .animation(.bouncy, value: viewModel.footer)
    }
}

@available(macOS 26.0, *)
private struct NewSessionActionsView: View {
    @Environment(SessionItemViewModel.self) var viewModel

    var body: some View {
        HStack(spacing: 22) {
            if !viewModel.slidesButtonIsHidden {
                Button {
                    viewModel.showSlides()
                } label: {
                    Image(systemName: "play.rectangle.on.rectangle.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                }
                .buttonStyle(SymbolButtonStyle())
                .help("Open slides")
                .transition(.scale.combined(with: .opacity))
            }

            Button {
                viewModel.toggleFavorite()
            } label: {
                Image(systemName: viewModel.isFavorite ? "star.fill" : "star")
                    .resizable()
                    .contentTransition(.symbolEffect(.replace.magic(fallback: .downUp.byLayer), options: .nonRepeating))
                    .aspectRatio(contentMode: .fit)
            }
            .buttonStyle(SymbolButtonStyle())
            .help(viewModel.isFavorite ? "Remove from favorites" : "Add to favorites")
            .transition(.scale.combined(with: .opacity))

            downloadButton

            if viewModel.downloadState == .downloaded {
                Button {
                    viewModel.shareClip()
                } label: {
                    Image(systemName: "scissors")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                }
                .buttonStyle(SymbolButtonStyle())
                .help("Share a Clip")
                .transition(.scale.combined(with: .opacity))
            }

            if !viewModel.calendarButtonIsHidden {
                Button {
                    viewModel.addCalendar()
                } label: {
                    Image(systemName: "calendar.badge.plus")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                }
                .buttonStyle(SymbolButtonStyle())
                .help("Add to Calendar")
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.bouncy, value: viewModel.slidesButtonIsHidden)
        .animation(.bouncy, value: viewModel.calendarButtonIsHidden)
        .animation(.bouncy, value: viewModel.downloadState)
        .frame(height: 24)
    }

    /// States managed by DownloadState enum:
    /// - .notDownloadable: no button, no progress (allocatesSpace: false)
    /// - .downloadable: shows download button (showsButton: true, help: "Download video for offline watching")
    /// - .pending: shows progress indicator without percentage (showsButton: false, help: "Preparing download")
    /// - .downloading(progress): shows progress indicator with percentage (showsButton: false, help: "Downloading: X%")
    /// - .downloaded: shows delete button (showsButton: true, help: "Delete downloaded video")
    @ViewBuilder var downloadButton: some View {
        if viewModel.downloadState.showsInlineButton {
            Button {
                switch viewModel.downloadState {
                case .notDownloadable:
                    break
                case .downloadable:
                    viewModel.download()
                case .pending, .downloading:
                    viewModel.cancelDownload()
                case .downloaded:
                    viewModel.deleteDownload()
                }
            } label: {
                switch viewModel.downloadState {
                case .notDownloadable, .downloadable:
                    Image(systemName: "arrow.down.document.fill").resizable()
                        .aspectRatio(contentMode: .fit)
                case .pending, .downloading:
                    let value = min(1.0, viewModel.downloadState.downloadProgress ?? 0)
                    Image(systemName: "xmark.circle", variableValue: value)
                        .resizable()
                        .symbolVariableValueMode(.draw)
                        .aspectRatio(contentMode: .fit)
                    // magical replace will crash somehow
                case .downloaded:
                    Image(systemName: "trash").resizable()
                        .aspectRatio(contentMode: .fit)
                }
            }
            .buttonStyle(SymbolButtonStyle())
            .help(downloadButtonHelp)
        }
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

@available(macOS 26.0, *)
private struct SymbolButtonStyle: ButtonStyle {
    @State private var isHovered = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.title)
            .foregroundStyle(Color.accentColor)
            .scaleEffect(configuration.isPressed ? 0.9 : 1) // scale content only
            .scaleEffect(isHovered ? 1.2 : 1)
            .animation(.bouncy(extraBounce: 0.3), value: configuration.isPressed)
            .animation(.smooth, value: isHovered)
            .onHover { isHovering in
                withAnimation {
                    isHovered = isHovering
                }
            }
    }
}
