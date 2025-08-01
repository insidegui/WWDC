//
//  NewExploreView.swift
//  WWDC
//
//  Created by luca on 01.08.2025.
//  Copyright © 2025 Guilherme Rambo. All rights reserved.
//

import AppKit
import SwiftUI

@available(macOS 26.0, *)
@Observable
class NewExploreViewModel {
    let provider: ExploreTabProvider

    var selectedCategory: String?
    var scrollPosition = ScrollPosition(idType: String.self)

    init(provider: ExploreTabProvider) {
        self.provider = provider
    }
}

@available(macOS 26.0, *)
struct NewExploreCategoryList: View {
    @State var viewModel: NewExploreViewModel
    @State private var sections: [ExploreTabContent.Section] = []
    var body: some View {
        ScrollViewReader { proxy in
            List(sections, selection: $viewModel.selectedCategory) { section in
                Label {
                    Text(section.title)
                } icon: {
                    section.icon
                }
            }
            .onChange(of: viewModel.selectedCategory) { oldValue, newValue in
                proxy.scrollTo(newValue, anchor: .bottom)
            }
        }
        .frame(width: 320)
        .onReceive(viewModel.provider.$content.receive(on: DispatchQueue.main)) { newContent in
            sections = newContent?.sections ?? []
            if viewModel.selectedCategory == nil {
                viewModel.selectedCategory = sections.first?.id
            }
        }
        .animation(.smooth, value: viewModel.selectedCategory)
    }
}

@available(macOS 26.0, *)
struct NewExploreTabRootView: View {
    @State var viewModel: NewExploreViewModel
    @State private var content: ExploreTabContent?

    var body: some View {
        Group {
            if let content = content {
                NewExploreTabContentView(content: content, currentPosition: $viewModel.selectedCategory)
                    .environment(viewModel)
                #if DEBUG
                    .contextMenu { Button("Export JSON…", action: content.exportJSON) }
                #endif
                    .transition(.blurReplace)
            } else {
                ExploreTabContentView(content: .placeholder, scrollOffset: .constant(.zero))
                    .redacted(reason: .placeholder)
                    .transition(.blurReplace)
            }
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
        .animation(.spring(), value: content?.id)
        .onReceive(viewModel.provider.$content.receive(on: DispatchQueue.main)) { newContent in
            content = newContent
        }
        .task {
            viewModel.provider.activate()
        }
    }
}

@available(macOS 26.0, *)
@MainActor
struct NewExploreTabContentView: View {
    static let cardImageCornerRadius: CGFloat = 8
    static let cardWidth: CGFloat = 240
    static let cardImageHeight: CGFloat = 134

    var content: ExploreTabContent

    @Environment(NewExploreViewModel.self) var viewModel
    @Binding var currentPosition: ExploreTabContent.Section.ID?

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
        .scrollPosition(id: $currentPosition, anchor: .top)
        .animation(.smooth, value: currentPosition)
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

struct TextButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .contentShape(Rectangle())
    }
}
