//
//  DetailDescriptionView.swift
//  WWDC
//
//  Created by luca on 05.08.2025.
//  Copyright © 2025 Guilherme Rambo. All rights reserved.
//

import Combine
import SwiftUI

extension NewSessionDetailView {
    struct SessionDescriptionView: View {
        let viewModel: SessionViewModel
        @State private var availableTabs: [SessionDetailsViewModel.SessionTab] = [.overview]
        @State private var tab: SessionDetailsViewModel.SessionTab = .overview
        @State private var isTranscriptAvailable = false
        @State private var isBookmarksAvailable = false

        var body: some View {
            Group {
                if availableTabs.count > 1 {
                    tabBar
                }
                switch tab {
                case .overview:
                    if #available(macOS 26.0, *) {
                        OverviewContentView(viewModel: viewModel)
                        RelatedSessionsView(currentSession: viewModel)
                    }
                case .transcript:
                    if #available(macOS 26.0, *) {
                        NewTranscriptView(viewModel: viewModel)
                    }
                case .bookmarks:
                    Text("Bookmarks view coming soon")
                        .foregroundColor(.secondary)
                }
            }
            .onReceive(transcriptAvailabilityUpdate) {
                if $0, !availableTabs.contains(.transcript) {
                    availableTabs.append(.transcript)
                } else if !$0 {
                    availableTabs.removeAll(where: { $0 == .transcript })
                }
            }
        }

        @ViewBuilder
        private var tabBar: some View {
            HStack(spacing: 32) {
                ForEach(availableTabs, id: \.self) { t in
                    Button(t.title) {
                        tab = t
                    }
                    .selected(tab == t)
                }
            }
            .buttonStyle(WWDCTextButtonStyle())
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
        }

        private var transcriptAvailabilityUpdate: AnyPublisher<Bool, Never> {
            viewModel.rxTranscript.replaceError(with: nil).map {
                $0 != nil
            }
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
        }
    }
}

private extension SessionDetailsViewModel.SessionTab {
    var title: String {
        switch self {
        case .overview:
            return "Overview"
        case .transcript:
            return "Transcript"
        case .bookmarks:
            return "Bookmarks"
        }
    }
}

@available(macOS 26.0, *)
private struct OverviewContentView: View {
    let viewModel: SessionViewModel
    @State private var title = ""
    @State private var summary = ""
    @State private var footer = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
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

    private func updates(for keyPath: KeyPath<SessionViewModel, some Publisher<String, any Error>>) -> AnyPublisher<String, Never>  {
        viewModel[keyPath: keyPath]
            .replaceError(with: "")
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
}
