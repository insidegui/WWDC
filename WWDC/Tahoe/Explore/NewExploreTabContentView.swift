//
//  NewExploreTabContentView.swift
//  WWDC
//
//  Created by luca on 06.08.2025.
//  Copyright © 2025 Guilherme Rambo. All rights reserved.
//

import SwiftUI

@available(macOS 26.0, *)
@MainActor
struct NewExploreTabContentView: View {
    static let cardImageCornerRadius: CGFloat = 8
    static let cardWidth: CGFloat = 240
    static let cardImageHeight: CGFloat = 134

    var content: ExploreTabContent

    @Environment(NewExploreViewModel.self) var viewModel

    @State private var isPresentingLiveEvent = false

    var body: some View {
        scrollView
            .overlay {
                if let liveItem = content.liveEventItem, isPresentingLiveEvent {
                    LiveStreamOverlay(item: liveItem) {
                        isPresentingLiveEvent = false
                    }
                    .animation(.default, value: content.isLiveEventStreaming)
                }
            }
            .onAppear {
                /// Automatically present live event item when even is currently live
                if content.isLiveEventStreaming {
                    isPresentingLiveEvent = true
                }
            }
    }

    @ViewBuilder
    private var scrollView: some View {
        @Bindable var viewModel = viewModel
        ScrollView(.vertical) {
            LazyVStack(alignment: .leading, spacing: 42) {
                liveHeader

                ForEach(content.sections) { section in
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 6) {
                            section.icon

                            Text(section.title)
                        }
                        .padding(.horizontal)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .padding(.leading, 2)
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(alignment: .top, spacing: 16) {
                                ForEach(section.items) { item in
                                    ExploreTabItemView(layout: section.layout, item: item)
                                        .contentShape(Rectangle())
                                        .onTapGesture { open(item) }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .id(section.id) // for scroll position to work perfectly
                }
            }
            .padding(.vertical)
            .blur(radius: isPresentingLiveEvent ? 24 : 0)
            .scrollTargetLayout()
        }
        .scrollPosition(id: $viewModel.selectedCategory, anchor: .center)
        .animation(.smooth, value: viewModel.selectedCategory)
    }

    @ViewBuilder
    private var liveHeader: some View {
        if let liveItem = content.liveEventItem {
            ExploreTabItemView(layout: .card, item: liveItem)
                .padding(.horizontal)
                .onTapGesture {
                    isPresentingLiveEvent = true
                }
        }
    }

    @MainActor
    private func open(_ item: ExploreTabContent.Item) {
        guard let destination = item.destination else {
            return
        }

        switch destination {
        case .command(let command):
            AppDelegate.run(command)
        case .url(let url):
            NSWorkspace.shared.open(url)
        }
    }
}
