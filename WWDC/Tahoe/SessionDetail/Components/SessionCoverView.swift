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
    var preferredImage: NSImage?
    var coverImageURL: URL?
    var isThumbnail: Bool = false
    @ViewBuilder let decoration: (_ image: Image, _ isPlaceHolder: Bool) -> Content
    private let image = State<NSImage>(initialValue: .noimage)
    @State private var isPlaceholder = true
    private let operation = State<AsyncImageOperation>(initialValue: .init())
    var body: some View {
        decoration(Image(nsImage: preferredImage ?? image.wrappedValue), preferredImage.flatMap { _ in false } ?? isPlaceholder)
            .transition(.blurReplace)
            .task(id: coverImageURL) {
                if isThumbnail {
                    await downloadCover(height: 50)
                } else {
                    await downloadCover()
                }
            }
            .animation(.smooth, value: isThumbnail)
    }

    @MainActor
    private func updateImage(_ img: NSImage?) {
        image.wrappedValue = img ?? .noimage
        isPlaceholder = img == nil
    }
}

private extension SessionCoverView {
    @ImageDownloadActor
    private func downloadCover(height: CGFloat? = nil) async {
        guard let url = coverImageURL else {
            return
        }
        let thumbnailOnly = (height ?? 999) <= Constants.thumbnailHeight
        let cached = ImageDownloadCenter.shared.cachedImage(from: url, thumbnailOnly: thumbnailOnly)
        if let cached {
            await updateImage(cached)
            return
        }
        guard !Task.isCancelled else {
            return
        }
        await operation.wrappedValue.cancel()
        let img = await operation.wrappedValue.download(from: url, thumbnailHeight: height, thumbnailOnly: thumbnailOnly)
        guard !Task.isCancelled else {
            return
        }
        await updateImage(img)
    }
}

/// isolate ImageDownloadCenter caching to this actor
@globalActor
private actor ImageDownloadActor {
    static let shared = ImageDownloadActor()
}

private class AsyncImageOperation {
    private weak var operation: Operation? // ImageDownloadCenter owns

    deinit {
        operation?.cancel()
//        print("AsyncImageOperation deinit")
    }

    func cancel() {
        operation?.cancel()
        operation = nil
    }

    func download(from url: URL, thumbnailHeight: CGFloat?, thumbnailOnly: Bool = false) async -> NSImage? {
        guard !Task.isCancelled else {
            return nil
        }

        return await withCheckedContinuation { continuation in
            var oneTimeContinuation: CheckedContinuation<NSImage?, Never>? = continuation
            operation?.cancel()
            operation = ImageDownloadCenter.shared.downloadImage(from: url, thumbnailHeight: thumbnailHeight, thumbnailOnly: thumbnailOnly) { _, result in
                defer {
                    oneTimeContinuation = nil
                }
                guard let img = thumbnailOnly ? (result.thumbnail ?? result.original) : result.original else {
                    oneTimeContinuation?.resume(returning: nil)
                    return
                }
                oneTimeContinuation?.resume(returning: img)
            }
        }
    }
}
