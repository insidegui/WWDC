//
//  LazyAsyncImage.swift
//  WWDC
//
//  Created by luca on 05.08.2025.
//  Copyright © 2025 Guilherme Rambo. All rights reserved.
//

import SwiftUI

/// LazyAsyncImage loads image **every time** before the view appears and cancel any pending operation when the view disappears
///
/// RemoteImage only loads small thumbnail **once**, changing that may affect other places
public struct LazyAsyncImage<I: View, P: View>: View {
    private let content: (Image) -> I
    private let placeholder: () -> P
    private let downloader: ImageDownloader
    private let animation: Animation?
    public init(url: URL?, height: CGFloat = 400, animation: Animation? = nil, @ViewBuilder content: @escaping (Image) -> I, @ViewBuilder placeholder: @escaping () -> P) {
        self.downloader = .init(url: url, height: height)
        self.placeholder = placeholder
        self.content = content
        self.animation = animation
    }

    public var body: some View {
        Group {
            if let image = downloader.image {
                content(Image(nsImage: image))
            } else {
                placeholder()
            }
        }
        .animation(animation, value: downloader.image)
        .task(id: downloader.url) {
            downloader.downloadImage()
        }
        .onDisappear {
            downloader.cancel()
        }
    }
}

@Observable
private class ImageDownloader {
    @ObservationIgnored private weak var currentImageDownloadOperation: Operation?
    @ObservationIgnored let url: URL?
    @ObservationIgnored let height: CGFloat
    var image: NSImage?

    init(url: URL?, height: CGFloat) {
        self.url = url
        if let url {
            image = ImageDownloadCenter.shared.cachedThumbnail(from: url)
        }
        self.height = height
    }

    func downloadImage() {
        currentImageDownloadOperation?.cancel()
        currentImageDownloadOperation = nil

        guard let imageUrl = url else {
            image = .noimage
            return
        }

        currentImageDownloadOperation = ImageDownloadCenter.shared.downloadImage(from: imageUrl, thumbnailHeight: height) { [weak self] url, result in
            self?.image = result.original
        }
    }

    func cancel() {
        currentImageDownloadOperation?.cancel()
        currentImageDownloadOperation = nil
    }
}
