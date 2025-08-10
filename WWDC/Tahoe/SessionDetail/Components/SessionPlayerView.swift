//
//  SessionPlayerView.swift
//  WWDC
//
//  Created by luca on 10.08.2025.
//  Copyright © 2025 Guilherme Rambo. All rights reserved.
//

import SwiftUI

@available(macOS 26.0, *)
struct SessionPlayerView: View {
    @Environment(SessionItemViewModel.self) private var viewModel
    @Environment(\.coordinator) private var coordinator
    @State private var coverRatio: CGFloat?
    @State private var isPlaying = false

    var body: some View {
        if isPlaying, let controller = coordinator?.currentPlayerController {
            GeometryReader { proxy in
                ViewControllerWrapper(viewController: controller, additionalSafeAreaInsets: proxy.safeAreaInsets)
                    .ignoresSafeArea()
            }.transition(.blurReplace)
            .aspectRatio(coverRatio, contentMode: .fit)
        } else {
            cover
        }
    }

    @ViewBuilder
    private var cover: some View {
        SessionCoverView(coverImageURL: viewModel.coverImageURL) { image, isPlaceholder in
            image.resizable()
                .aspectRatio(contentMode: .fit)
                .extendBackground()
        }
        .onGeometryChange(for: CGSize.self, of: { proxy in
            proxy.size
        }, action: { newValue in
            if newValue.height > 0 {
                coverRatio = newValue.width / newValue.height
            }
        })
        .overlay(alignment: .center) {
            Button {
                guard let session = viewModel.session, let storage = coordinator?.storage else {
                    return
                }
                do {
                    let model = try PlaybackViewModel(sessionViewModel: session, storage: storage)
                    let viewController = VideoPlayerViewController(player: model.player, session: model.sessionViewModel, shelf: nil)
                    viewController.delegate = coordinator
                    viewController.playerView.timelineDelegate = coordinator
                    coordinator?.currentPlayerController = viewController
                    withAnimation {
                        isPlaying = true
                    }
                } catch {
                    print("failed to create player: \(error)")
                }
            } label: {
                Label("Play", systemImage: "play.fill")
            }
            .controlSize(.extraLarge)
            .buttonStyle(.glass)
            .tint(.black.opacity(0.3)) // make the label more readable
            .hoverEffect(scale: 1.1)
        }
    }
}
