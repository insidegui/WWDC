//
//  NewExploreTabDetailView.swift
//  WWDC
//
//  Created by luca on 06.08.2025.
//  Copyright © 2025 Guilherme Rambo. All rights reserved.
//

import SwiftUI

@available(macOS 26.0, *)
struct NewExploreTabDetailView: View {
    @Environment(NewExploreViewModel.self) var viewModel
    @State private var content: ExploreTabContent?

    var body: some View {
        Group {
            if let content = content {
                @Bindable var model = viewModel
                NewExploreTabContentView(content: content)
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
        .onReceive(viewModel.provider.$content.receive(on: DispatchQueue.main)) { newContent in
            content = newContent
        }
        .task {
            viewModel.provider.activate()
        }
    }
}
