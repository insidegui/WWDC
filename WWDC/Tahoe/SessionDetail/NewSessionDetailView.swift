//
//  NewSessionDetailView.swift
//  WWDC
//
//  Created by luca on 05.08.2025.
//  Copyright © 2025 Guilherme Rambo. All rights reserved.
//

import Combine
import SwiftUI

struct NewSessionDetailView: View {
    let viewModel: SessionViewModel
    @State private var tab: SessionDetailsViewModel.SessionTab = .overview
    var body: some View {
        if #available(macOS 26.0, *) {
            ScrollView {
                SessionDetailThumbnailView(viewModel: viewModel)
                SessionDescriptionView(viewModel: viewModel)
            }
            .ignoresSafeArea(edges: .top)
            .scrollEdgeEffectStyle(.soft, for: .vertical)
        }
    }
}
