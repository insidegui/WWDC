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
struct NewSessionDetailWrapperView: View {
    @Environment(SessionListViewModel.self) var viewModel
    var body: some View {
        if let session = viewModel.selectedSession {
            NewSessionDetailView()
                .environment(session.model)
                .transition(.blurReplace)
        } else {
            Color.clear
        }
    }
}

@available(macOS 26.0, *)
struct NewSessionDetailView: View {
    @Environment(SessionItemViewModel.self) var viewModel
    @State private var availableTabs: [SessionDetailsViewModel.SessionTab] = [.overview]
    @State private var tab: SessionDetailsViewModel.SessionTab = .overview
    @State private var scrollPosition = ScrollPosition()
    var body: some View {
        ScrollView {
            SessionDescriptionView(tab: $tab, scrollPosition: $scrollPosition)
        }
        .scrollPosition($scrollPosition, anchor: .top)
        .safeAreaBar(edge: .top) {
            VStack(alignment: .leading, spacing: 0) {
                SessionCoverView(coverImageURL: viewModel.coverImageURL) { image, isPlaceholder in
                    image.resizable()
                        .aspectRatio(contentMode: .fit)
                        .extendBackground()
                }
                if availableTabs.count > 1 {
                    tabBar
                }
            }
        }
        .ignoresSafeArea(edges: .top)
        .scrollEdgeEffectStyle(.soft, for: .vertical)
        .onReceive(transcriptAvailabilityUpdate) {
            if $0, !availableTabs.contains(.transcript) {
                availableTabs.append(.transcript)
            } else if !$0 {
                availableTabs.removeAll(where: { $0 == .transcript })
                if tab == .transcript {
                    tab = availableTabs.first ?? .overview
                }
            }
        }
    }

    @ViewBuilder
    private var tabBar: some View {
        Picker("", selection: $tab) {
            ForEach(availableTabs, id: \.self) { t in
                Text(t.title)
            }
        }
        .pickerStyle(.segmented)
        .controlSize(.large)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private var transcriptAvailabilityUpdate: AnyPublisher<Bool, Never> {
        viewModel.session?.rxTranscript.replaceError(with: nil).map {
            $0 != nil
        }
        .removeDuplicates()
        .receive(on: DispatchQueue.main)
        .eraseToAnyPublisher() ?? Just(false).eraseToAnyPublisher()
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
