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
    var body: some View {
        Group {
            if let image = imageOfInterest {
                decoration(Image(nsImage: image), false)
                    .transition(.blurReplace)
                    .task(id: viewModel.coverImageURL) {
                        if !isThumbnail {
                            await viewModel.downloadFullCoverIfNeeded()
                        }
                    }
            } else {
                decoration(Image(.noimage), true)
                    .transition(.blurReplace)
                    .task(id: viewModel.coverImageURL) {
                        if isThumbnail {
                            await viewModel.downloadSmallCoverIfNeeded()
                        } else {
                            await viewModel.downloadFullCoverIfNeeded()
                        }
                    }
            }
        }
        .animation(.smooth, value: imageOfInterest)
    }

    var imageOfInterest: NSImage? {
        if isThumbnail {
            return viewModel.smallCover
        } else {
            return viewModel.fullCover ?? viewModel.smallCover
        }
    }
}
