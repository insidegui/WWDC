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
    let viewModel: SessionViewModel
    @State private var tab: SessionDetailsViewModel.SessionTab = .overview
    var body: some View {
        ScrollView {
            SessionDetailThumbnailView(viewModel: viewModel)
            SessionDescriptionView(viewModel: viewModel)
        }
        .ignoresSafeArea(edges: .top)
        .scrollEdgeEffectStyle(.soft, for: .vertical)
    }
}

@available(macOS 26.0, *)
struct NewSessionDetailWrapperView: View {
    @Bindable var viewModel: SessionListViewModel
    var body: some View {
        if let session = viewModel.selectedSession {
            NewSessionDetailView(viewModel: session.model)
                .transition(.blurReplace)
        } else {
            Color.clear
        }
    }
}
