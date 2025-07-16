//
//  SessionCellView.swift
//  WWDC
//
//  Created by Guilherme Rambo on 13/05/18.
//  Copyright © 2018 Guilherme Rambo. All rights reserved.
//

import Cocoa
import SwiftUI
import Combine
import RealmSwift
import ConfCore

final class SessionCellViewModel: ObservableObject {
    @Published var title: String = ""
    @Published var subtitle: String = ""
    @Published var context: String = ""
    @Published var isFavorite: Bool = false
    @Published var isDownloaded: Bool = false
    @Published var contextColor: NSColor = .clear
    @Published var imageUrl: URL?
    @Published var thumbnailImage: NSImage = #imageLiteral(resourceName: "noimage")

    @Published private var sessionProgress: SessionProgress?
    var progress: Double { sessionProgress.flatMap(\.relativePosition) ?? 1 }

    var isWatched: Bool {
        sessionProgress != nil && progress >= Constants.watchedVideoRelativePosition
    }
    
    private var cancellables: Set<AnyCancellable> = []
    private weak var imageDownloadOperation: Operation?
    
    var viewModel: SessionViewModel? {
        didSet {
            guard viewModel !== oldValue else { return }

            thumbnailImage = #imageLiteral(resourceName: "noimage")
            bindUI()
        }
    }

    init(session: SessionViewModel? = nil) {
        defer {
            self.viewModel = session
        }
    }

    private func bindUI() {
        cancellables = []

        guard let viewModel = viewModel else { return }

        // While it might seem like we can do `.assign(to: &$title)`, we actually can't because
        // both SessionViewModel and SessionCellViewModel are long lived items.
        //
        // SessionCellViewModel is recycled, so when a new SessionViewModel is attached, we need to break the
        // bindings with the previous one. Which means we MUST have a cancellables for as long as this is the architecture we have
        viewModel.rxTitle.replaceError(with: "").assign(to: \.title, on: self).store(in: &cancellables)
        viewModel.rxSubtitle.replaceError(with: "").assign(to: \.subtitle, on: self).store(in: &cancellables)
        viewModel.rxContext.replaceError(with: "").assign(to: \.context, on: self).store(in: &cancellables)
        viewModel.rxIsFavorite.replaceError(with: false).assign(to: \.isFavorite, on: self).store(in: &cancellables)
        viewModel.rxIsDownloaded.replaceError(with: false).assign(to: \.isDownloaded, on: self).store(in: &cancellables)
        viewModel.rxColor.removeDuplicates().replaceError(with: .clear).assign(to: \.contextColor, on: self).store(in: &cancellables)

        viewModel.rxImageUrl.removeDuplicates().replaceErrorWithEmpty().compacted().sink { [weak self] imageUrl in
            self?.imageUrl = imageUrl
            self?.imageDownloadOperation?.cancel()

            self?.imageDownloadOperation = ImageDownloadCenter.shared.downloadImage(from: imageUrl, thumbnailHeight: Constants.thumbnailHeight, thumbnailOnly: true) { [weak self] url, result in
                guard url == imageUrl, let thumbnail = result.thumbnail else { return }

                self?.thumbnailImage = thumbnail
            }
        }
        .store(in: &cancellables)

        viewModel.rxProgresses.replaceErrorWithEmpty().map(\.first).assign(to: \.sessionProgress, on: self).store(in: &cancellables)
    }
}

struct SessionCellView: View {
    @ObservedObject var cellViewModel: SessionCellViewModel
    let style: Style

    var body: some View {
        HStack(spacing: 0) {
            ProgressView(value: cellViewModel.progress, total: 1.0)
                .progressViewStyle(TrackColorProgressViewStyle())
                .foregroundStyle(Color(cellViewModel.contextColor))
                .opacity(cellViewModel.isWatched ? 0 : 1)

            Image(nsImage: cellViewModel.thumbnailImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 85, height: 48)
                .clipped()
                .padding(.horizontal, 8)

            informationLabels

            statusIcons
        }
        .padding(.leading, 10)
        .padding(.vertical, 8)
        .background(style == .rounded ? Color(.roundedCellBackground) : Color.clear)
        .cornerRadius(style == .rounded ? 6 : 0)
        .frame(height: 64)
    }

    /// Discover Apple-Hosted Background Assets
    /// WWDC25 • Session 325
    /// System Services
    private var informationLabels: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(cellViewModel.title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color(.primaryText))

            Text(cellViewModel.subtitle)
                .font(.system(size: 12))
                .foregroundStyle(Color(.secondaryText))

            Text(cellViewModel.context)
                .font(.system(size: 12))
                .foregroundStyle(Color(.tertiaryText))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .lineLimit(1)
        .truncationMode(.tail)
    }

    private var statusIcons: some View {
        // Icons
        VStack(spacing: 0) {
            Image(.starSmall)
                .resizable()
                .scaledToFit()
                .frame(height: 14)
                .opacity(cellViewModel.isFavorite ? 1 : 0)

            Spacer()

            Image(.downloadSmall)
                .resizable()
                .scaledToFit()
                .frame(height: 11)
                .opacity(cellViewModel.isDownloaded ? 1 : 0)
        }
    }
}

extension SessionCellView {
    enum Style {
        /// Used for session lists
        case flat
        /// Used for related sessions
        case rounded
    }
}

#Preview {
    VStack {
        SessionCellView(cellViewModel: SessionCellViewModel(session: .preview), style: .flat)
            .padding()

        Divider()

        SessionCellView(cellViewModel: SessionCellViewModel(session: .preview), style: .rounded)
            .padding()
    }
    .padding()
}
