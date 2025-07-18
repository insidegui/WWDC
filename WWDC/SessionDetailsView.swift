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
    @ObservedObject var detailsViewModel: SessionDetailsViewModel
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                ShelfViewControllerWrapper(controller: detailsViewModel.shelfController)
                    .layoutPriority(1)
                    .frame(minHeight: 280, maxHeight: .infinity)
                    .padding(.top, 22)

                if detailsViewModel.isTranscriptAvailable || detailsViewModel.isBookmarksAvailable {
                    tabButtons
                }

                Divider()

                tabContent(geometry: geometry)
                    .border(.purple, width: 3)
//                    .frame(maxHeight: geometry.size.height / 2)
//                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 16)
            }
//            .frame(maxHeight: geometry.size.height)
            .padding([.bottom, .horizontal], 46)
        }
        .border(.yellow, width: 5)
    }
    
    private var tabButtons: some View {
        HStack(spacing: 28) {
            Button("Overview") {
                withAnimation(.snappy) {
                    detailsViewModel.selectedTab = .overview
                }
            }
            .selected(detailsViewModel.selectedTab == .overview)

            if detailsViewModel.isTranscriptAvailable {
                Button("Transcript") {
                    withAnimation(.snappy) {
                        detailsViewModel.selectedTab = .transcript
                    }
                }
                .selected(detailsViewModel.selectedTab == .transcript)
            }
            
            if detailsViewModel.isBookmarksAvailable {
                Button("Bookmarks") {
                    detailsViewModel.selectedTab = .bookmarks
                }
                .selected(detailsViewModel.selectedTab == .bookmarks)
            }
        }
        .buttonStyle(WWDCTextButtonStyle())
//        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func tabContent(geometry: GeometryProxy) -> some View {
        if let session = detailsViewModel.viewModel {
            SessionSummaryView(viewModel: session)
                .opacity(detailsViewModel.selectedTab == .transcript ? 0 : 1)
                .overlay {
                    SessionTranscriptViewControllerWrapper(controller: detailsViewModel.transcriptController)
                        .opacity(detailsViewModel.selectedTab == .transcript ? 1 : 0)
                }
        }
        //        switch detailsViewModel.selectedTab {
        //        case .overview:
        //
        //        case .transcript:
        //
        //                .frame(maxHeight: geometry.size.height / 3)
        //        case .bookmarks:
        //            Text("Bookmarks view coming soon")
        //                .foregroundColor(.secondary)
        //        }
    }
}

struct SessionDetailsView_Previews: PreviewProvider {
    static var previews: some View {
        SessionDetailsView(detailsViewModel: SessionDetailsViewModel(session: .preview))
    }
}
