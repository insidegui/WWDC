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
    @State private var isLoadingThumbnail = true

    var body: some View {
        Group {
            if
                viewModel.isPlaying,
                let controller = coordinator?.currentShelfViewController,
                controller.viewModel?.identifier == viewModel.session?.identifier // check again when reusing
            {
                GeometryReader { proxy in
                    ViewControllerWrapper(viewController: controller, additionalSafeAreaInsets: proxy.safeAreaInsets)
                        .ignoresSafeArea()
                }
                .transition(.blurReplace)
            } else {
                cover
                    .transition(.blurReplace)
            }
        }
        .aspectRatio(coverRatio, contentMode: .fit)
        .task(id: viewModel.session?.identifier) { [weak coordinator, weak viewModel] in
            viewModel?.isPlaying = coordinator?.currentShelfViewController?.viewModel?.identifier == viewModel?.session?.identifier
        }
    }

    @ViewBuilder
    private var cover: some View {
        SessionCoverView(coverImageURL: viewModel.coverImageURL) { image, isPlaceholder in
            image.resizable()
                .aspectRatio(contentMode: .fit)
                .extendBackground()
                .transition(.blurReplace)
                .animation(.smooth, value: isPlaceholder)
                .task(id: isPlaceholder) {
                    isLoadingThumbnail = isPlaceholder
                }
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
                guard let session = viewModel.session else {
                    return
                }
                defer {
                    viewModel.isPlaying = true
                }
                if let existing = coordinator?.currentShelfViewController {
                    existing.viewModel = session
                    existing.playButton.isHidden = true
                    existing.play(nil)
                    return
                }
                let viewController = ShelfViewController()
                viewController.viewModel = session
                viewController.delegate = coordinator
                viewController.playButton.isHidden = true
                coordinator?.currentShelfViewController = viewController
                viewController.play(nil)
            } label: {
                Label("Play", systemImage: "play.fill")
            }
            .controlSize(.extraLarge)
            .buttonBorderShape(.capsule)
            .buttonStyle(.glass)
            .hoverEffect(scale: 1.1)
            .disabled(isLoadingThumbnail)
        }
    }
}
