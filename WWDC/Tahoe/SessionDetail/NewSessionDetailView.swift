//
//  NewSessionDetailView.swift
//  WWDC
//
//  Created by luca on 05.08.2025.
//  Copyright © 2025 Guilherme Rambo. All rights reserved.
//

import Combine
import SwiftUI

@available(macOS 26.0, *)
struct NewSessionDetailView: View {
    @Environment(SessionItemViewModel.self) var viewModel
    @Environment(GlobalSearchCoordinator.self) var searchCoordinator
    @State private var availableTabs: [SessionDetailsViewModel.SessionTab] = [.overview]
    @State private var tab: SessionDetailsViewModel.SessionTab = .overview
    @State private var scrollPosition = ScrollPosition()
    var body: some View {
        ScrollView {
            SessionDescriptionView(tab: $tab, scrollPosition: $scrollPosition)
        }
        .scrollPosition($scrollPosition, anchor: .center)
        .safeAreaBar(edge: .top) {
            VStack(alignment: .leading, spacing: 0) {
                SessionPlayerView()
                if availableTabs.count > 1 {
                    tabBar
                }
            }
        }
        .ignoresSafeArea(edges: .top)
        .scrollEdgeEffectStyle(.soft, for: .vertical)
        .task(id: viewModel.isTranscriptAvailable) {
            let newValue = viewModel.isTranscriptAvailable
            if newValue, !availableTabs.contains(.transcript) {
                availableTabs.append(.transcript)
                searchCoordinator.availableSearchTargets = [.sessions, .transcripts]
            } else if !newValue {
                availableTabs.removeAll(where: { $0 == .transcript })
                searchCoordinator.availableSearchTargets = [.sessions]
                if tab == .transcript {
                    tab = availableTabs.first ?? .overview
                }
            }
        }
        .onChange(of: tab) { oldValue, newValue in
            if newValue == .transcript {
                searchCoordinator.searchTarget = .transcripts
            } else {
                searchCoordinator.searchTarget = .sessions
            }
        }
        .onChange(of: searchCoordinator.searchTarget) { oldValue, newValue in
            if newValue == .transcripts, tab != .transcript, availableTabs.contains(.transcript) {
                withAnimation {
                    tab = .transcript
                }
            }
        }
    }

    @ViewBuilder
    private var tabBar: some View {
        Picker("Tabs", selection: $tab) {
            ForEach(availableTabs, id: \.self) { t in
                Text(t.title)
            }
        }
        .labelsHidden()
        .pickerStyle(.segmented)
        .controlSize(.large)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
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
