//
//  SessionCoverView.swift
//  WWDC
//
//  Created by luca on 05.08.2025.
//  Copyright © 2025 Guilherme Rambo. All rights reserved.
//

import Combine
import SwiftUI

struct SessionCoverView<Content: View>: View {
    @Environment(SessionItemViewModel.self) var viewModel
    var isThumbnail: Bool = false
    @ViewBuilder let decoration: (_ image: Image, _ isPlaceHolder: Bool) -> Content
    @State private var image = Image(.noimage)
    @State private var isPlaceholder = true
    private let operation = State<Operation?>()
    var body: some View {
        decoration(image, isPlaceholder)
            .transition(.blurReplace)
            .task(id: viewModel.coverImageURL, priority: .background) {
                if isThumbnail {
                    await downloadCover(height: Constants.thumbnailHeight)
                } else {
                    await downloadCover(height: 400)
                }
            }
            .animation(.smooth, value: isThumbnail)
    }

    @MainActor
    private func updateImage(_ img: NSImage?) {
        image = img.flatMap(Image.init(nsImage:)) ?? Image(.noimage)
        isPlaceholder = img == nil
    }
}

private extension SessionCoverView {
    @ImageDownloadActor
    private func downloadCover(height: CGFloat) async {
        guard let url = await viewModel.coverImageURL else {
            return
        }
        let thumbnailOnly = height <= Constants.thumbnailHeight
        let cached = ImageDownloadCenter.shared.cachedImage(from: url, thumbnailOnly: thumbnailOnly)
        if let cached {
            await updateImage(cached)
            return
        }
        operation.wrappedValue?.cancel()
        operation.wrappedValue = nil
        operation.wrappedValue = ImageDownloadCenter.shared.downloadImage(from: url, thumbnailHeight: height, thumbnailOnly: thumbnailOnly) { _, result in
            guard let img = thumbnailOnly ? result.thumbnail : result.original else {
                DispatchQueue.main.async {
                    updateImage(nil)
                }
                return
            }
            DispatchQueue.main.async {
                updateImage(img)
            }
        }
    }
}

/// isolate ImageDownloadCenter caching to this actor
@globalActor
actor ImageDownloadActor {
    static let shared = ImageDownloadActor()
}
