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
        let viewModel: SessionViewModel
        @Binding var tab: SessionDetailsViewModel.SessionTab
        let transcriptPosition: Binding<ScrollPosition>

        var body: some View {
            Group {
                switch tab {
                case .overview:
                    if #available(macOS 26.0, *) {
                        OverviewContentView(viewModel: viewModel)
                        RelatedSessionsView(currentSession: viewModel)
                    }
                case .transcript:
                    if #available(macOS 26.0, *) {
                        NewTranscriptView(viewModel: viewModel, scrollPosition: transcriptPosition)
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
    let viewModel: SessionViewModel
    private let actionsViewModel: SessionActionsViewModel
    init(viewModel: SessionViewModel) {
        self.viewModel = viewModel
        self.actionsViewModel = SessionActionsViewModel(session: viewModel)
    }

    @State private var title = ""
    @State private var summary = ""
    @State private var footer = ""
    @Environment(\.coordinator) private var appCoordinator
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                Text(title)
                    .font(.init(NSFont.boldTitleFont))
                    .foregroundStyle(.primary)
                    .kerning(-0.5)
                    .textSelection(.enabled)
                    .transition(.blurReplace)
                    .onReceive(updates(for: \.rxTitle)) { newValue in
                        withAnimation {
                            title = newValue
                        }
                    }
                Spacer()
                NewSessionActionsView(viewModel: actionsViewModel, alignment: .trailing)
                    .task {
                        actionsViewModel.delegate = appCoordinator
                    }
            }
            Text(summary)
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .lineHeight(.multiple(factor: 1.2))
                .textSelection(.enabled)
                .transition(.blurReplace)
                .onReceive(updates(for: \.rxSummary)) { newValue in
                    withAnimation {
                        summary = newValue
                    }
                }
            Text(footer)
                .font(.system(size: 16))
                .foregroundStyle(.tertiary)
                .allowsTightening(true)
                .truncationMode(.tail)
                .textSelection(.enabled)
                .transition(.blurReplace)
                .onReceive(updates(for: \.rxFooter)) { newValue in
                    withAnimation {
                        footer = newValue
                    }
                }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding([.bottom, .horizontal])
        .padding(.top, 8) // incase tabs are hidden
    }

    private func updates(for keyPath: KeyPath<SessionViewModel, some Publisher<String, any Error>>) -> AnyPublisher<String, Never> {
        viewModel[keyPath: keyPath]
            .replaceError(with: "")
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
}

@available(macOS 26.0, *)
private struct NewSessionActionsView: View {
    @ObservedObject var viewModel: SessionActionsViewModel
    var alignment = Alignment.leading

    var body: some View {
        HStack(spacing: 22) {
            if !viewModel.slidesButtonIsHidden {
                Button {
                    viewModel.showSlides()
                } label: {
                    Image(systemName: "play.rectangle.on.rectangle.fill")
                }
                .buttonStyle(SymbolButtonStyle())
                .help("Open slides")
                .transition(.blurReplace)
            }

            Button {
                viewModel.toggleFavorite()
            } label: {
                Image(systemName: viewModel.isFavorited ? "star.fill" : "star")
            }
            .buttonStyle(SymbolButtonStyle())
            .help(viewModel.isFavorited ? "Remove from favorites" : "Add to favorites")
            .transition(.blurReplace)

            downloadButton

            if viewModel.downloadState == .downloaded {
                Button {
                    viewModel.shareClip()
                } label: {
                    Image(systemName: "scissors")
                }
                .buttonStyle(SymbolButtonStyle())
                .help("Share a Clip")
                .transition(.blurReplace)
            }

            if !viewModel.calendarButtonIsHidden {
                Button {
                    viewModel.addCalendar()
                } label: {
                    Image(systemName: "calendar.badge.plus")
                }
                .buttonStyle(SymbolButtonStyle())
                .help("Add to Calendar")
                .transition(.blurReplace)
            }
        }
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
                if viewModel.downloadState == .downloaded {
                    viewModel.deleteDownload()
                } else {
                    viewModel.download()
                }
            } label: {
                Image(systemName: viewModel.downloadState == .downloaded ? "trash" : "arrow.down.circle", variableValue: viewModel.downloadState.downloadProgress ?? 0)
            }
            .buttonStyle(SymbolButtonStyle())
            .help(downloadButtonHelp)
            .transition(.blurReplace)
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
            .symbolVariableValueMode(.draw)
            .contentTransition(.symbolEffect(.replace.magic(fallback: .offUp.wholeSymbol), options: .nonRepeating))
            .font(.title)
            .foregroundStyle(Color.accentColor)
            .scaleEffect(configuration.isPressed ? 0.9 : 1) // scale content only
            .opacity((isHovered || configuration.isPressed) ? 0.7 : 1)
            .animation(.bouncy(extraBounce: 0.3), value: configuration.isPressed)
            .animation(.smooth, value: isHovered)
            .padding(5)
            .frame(width: 30, height: 30)
            .contentShape(Rectangle())
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .onHover { isHovering in
                withAnimation {
                    isHovered = isHovering
                }
            }
    }
}
