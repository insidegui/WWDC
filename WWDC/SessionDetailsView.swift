//
//  SessionDetailsView.swift
//  WWDC
//
//  Created by Allen Humphreys on 7/9/25.
//  Copyright © 2025 Guilherme Rambo. All rights reserved.
//

import SwiftUI

/**
 View for displaying session details with video player and tabbed content.

 This view is the right hand side of the split views for each of schedule and sessions app-level tabs.

 Visual Structure:
 ┌─────────────────────────────────────────────────┐
 │                                                 │
 │         ShelfViewControllerWrapper              │
 │              (Video Player)                     │
 │                                                 │
 └─────────────────────────────────────────────────┘
 
 ┌─────────────────────────────────────────────────┐
 │  [Overview] [Transcript] [Bookmarks]            │
 │ ─────────────────────────────────────────────── │
 │                                                 │
 │              Tab Content Area                   │
 │                                                 │
 │  • Overview: SessionSummaryView                 │
 │  • Transcript: SessionTranscriptViewController  │
 │  • Bookmarks: Placeholder text                  │
 │                                                 │
 └─────────────────────────────────────────────────┘
 */
struct SessionDetailsView: View {
    @ObservedObject var viewModel: SessionDetailsViewModel

    var body: some View {
        VStack(spacing: 0) {
            ShelfViewControllerWrapper(controller: viewModel.shelfController)
                .frame(minHeight: 280, maxHeight: .infinity)
                .padding(.top, 22)

            if viewModel.isTranscriptAvailable || viewModel.isBookmarksAvailable {
                tabButtons
            }

            Divider()

            tabContent
                .padding(.top, 16)
        }
        .padding([.bottom, .horizontal], 46)
    }
    
    private var tabButtons: some View {
        HStack(spacing: 28) {
            Button("Overview") {
                withAnimation(.snappy) {
                    viewModel.selectedTab = .overview
                }
            }
            .selected(viewModel.selectedTab == .overview)

            if viewModel.isTranscriptAvailable {
                Button("Transcript") {
                    withAnimation(.snappy) {
                        viewModel.selectedTab = .transcript
                    }
                }
                .selected(viewModel.selectedTab == .transcript)
            }
            
            if viewModel.isBookmarksAvailable {
                Button("Bookmarks") {
                    viewModel.selectedTab = .bookmarks
                }
                .selected(viewModel.selectedTab == .bookmarks)
            }
        }
        .buttonStyle(WWDCTextButtonStyle())
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var tabContent: some View {
        switch viewModel.selectedTab {
        case .overview:
            SessionSummaryView(viewModel: viewModel.summaryViewModel)
        case .transcript:
            SessionTranscriptViewControllerWrapper(controller: viewModel.transcriptController)
        case .bookmarks:
            Text("Bookmarks view coming soon")
                .foregroundColor(.secondary)
        }
    }
}

struct SessionDetailsView_Previews: PreviewProvider {
    static var previews: some View {
        SessionDetailsView(viewModel: SessionDetailsViewModel(session: .preview))
    }
}
