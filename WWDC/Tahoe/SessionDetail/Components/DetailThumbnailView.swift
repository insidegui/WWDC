//
//  DetailThumbnailView.swift
//  WWDC
//
//  Created by luca on 05.08.2025.
//  Copyright © 2025 Guilherme Rambo. All rights reserved.
//

import Combine
import SwiftUI

@available(macOS 26.0, *)
extension NewSessionDetailView {
    struct SessionDetailThumbnailView: View {
        let viewModel: SessionViewModel
        @State private var thumbnailURL: URL?

        var body: some View {
            LazyAsyncImage(url: thumbnailURL, greedy: false, animation: .bouncy) { newImg in
                newImg
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .extendBackground()
            } placeholder: {
                Image("noimage")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }
            .onReceive(imageUpdate) { newImageUrl in
                thumbnailURL = newImageUrl
            }
        }

        var imageUpdate: AnyPublisher<URL?, Never> {
            viewModel.rxImageUrl.replaceErrorWithEmpty()
                .receive(on: DispatchQueue.main)
                .removeDuplicates()
                .eraseToAnyPublisher()
        }
    }
}
