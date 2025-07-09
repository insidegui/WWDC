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
 │  • Overview: SessionSummaryViewControllerWrapper│
 │  • Transcript: SessionTranscriptViewController  │
 │  • Bookmarks: Placeholder text                  │
 │                                                 │
 └─────────────────────────────────────────────────┘
 */
struct SessionDetailsView: View {
    @ObservedObject var detailsViewModel: SessionDetailsViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            ShelfViewControllerWrapper(controller: detailsViewModel.shelfController)
                .layoutPriority(1)
                .frame(minHeight: 280, maxHeight: .infinity)
                .padding(.top, 22)

            VStack(spacing: 0) {
                if detailsViewModel.isTranscriptAvailable || detailsViewModel.isBookmarksAvailable {
                    tabButtons
                }

                Divider()

                tabContent
                    .padding(.top, 16)
            }
        }
        .padding([.bottom, .horizontal], 46)
    }
    
    private var tabButtons: some View {
        HStack(spacing: 32) {
            Button("Overview") {
                detailsViewModel.selectedTab = .overview
            }
            .buttonStyle(WWDCTextButtonStyle(isSelected: detailsViewModel.selectedTab == .overview))
            
            if detailsViewModel.isTranscriptAvailable {
                Button("Transcript") {
                    detailsViewModel.selectedTab = .transcript
                }
                .buttonStyle(WWDCTextButtonStyle(isSelected: detailsViewModel.selectedTab == .transcript))
            }
            
            if detailsViewModel.isBookmarksAvailable {
                Button("Bookmarks") {
                    detailsViewModel.selectedTab = .bookmarks
                }
                .buttonStyle(WWDCTextButtonStyle(isSelected: detailsViewModel.selectedTab == .bookmarks))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private var tabContent: some View {
        switch detailsViewModel.selectedTab {
        case .overview:
            SessionSummaryViewControllerWrapper(controller: detailsViewModel.summaryController)
        case .transcript:
            SessionTranscriptViewControllerWrapper(controller: detailsViewModel.transcriptController)
        case .bookmarks:
            Text("Bookmarks view coming soon")
                .foregroundColor(.secondary)
        }
    }
}
