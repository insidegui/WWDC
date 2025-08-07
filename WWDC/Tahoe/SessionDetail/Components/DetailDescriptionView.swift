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
                SessionActionsView(viewModel: actionsViewModel, alignment: .trailing)
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

    private func updates(for keyPath: KeyPath<SessionViewModel, some Publisher<String, any Error>>) -> AnyPublisher<String, Never>  {
        viewModel[keyPath: keyPath]
            .replaceError(with: "")
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
}
