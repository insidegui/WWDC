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
    @Published var hasBookmarks: Bool = false
    @Published var isDownloaded: Bool = false
    @Published var contextColor: NSColor = .clear
    @Published var thumbnailImage: NSImage?

    @Published private var sessionProgress: SessionProgress?
    var progress: Double { sessionProgress.flatMap(\.relativePosition) ?? 1 }

    var isWatched: Bool {
        sessionProgress != nil && progress >= Constants.watchedVideoRelativePosition
    }
    
    private var cancellables: Set<AnyCancellable> = []
    private var imageDownloadOperation: DownloadOperation?

    static let placeholderImage = NSImage(resource: .noImageAvailable)

    @MainActor
    var viewModel: SessionViewModel? {
        didSet {
            guard viewModel !== oldValue else { return }

            bindUI()
        }
    }

    @MainActor
    init(session: SessionViewModel? = nil) {
        defer {
            self.viewModel = session
        }
    }

    @MainActor
    private func bindUI() {
        cancellables = []
        thumbnailImage = nil

        guard let viewModel = viewModel else {
            imageDownloadOperation?.task.cancel()
            imageDownloadOperation = nil
            return
        }

        // Immediate values
        self.title = viewModel.title
        self.subtitle = viewModel.subtitle
        self.context = viewModel.context
        self.isFavorite = viewModel.isFavorite
        self.isDownloaded = viewModel.isDownloaded
        self.contextColor = viewModel.color ?? .clear
        self.sessionProgress = viewModel.progress

        loadSessionImage(at: viewModel.imageURL, for: viewModel.identifier)

        // Reactive updates

        viewModel.connect()
        viewModel.$title.dropFirst().weakAssignIfDifferent(to: \.title, on: self).store(in: &self.cancellables)
        viewModel.$subtitle.dropFirst().weakAssignIfDifferent(to: \.subtitle, on: self).store(in: &self.cancellables)
        viewModel.$context.dropFirst().weakAssignIfDifferent(to: \.context, on: self).store(in: &self.cancellables)
        viewModel.$isFavorite.dropFirst().weakAssignIfDifferent(to: \.isFavorite, on: self).store(in: &self.cancellables)
        viewModel.$hasBookmarks.dropFirst().weakAssignIfDifferent(to: \.hasBookmarks, on: self).store(in: &self.cancellables)
        viewModel.$isDownloaded.dropFirst().weakAssignIfDifferent(to: \.isDownloaded, on: self).store(in: &self.cancellables)
        viewModel.$color.dropFirst().map { $0 ?? .clear }.weakAssignIfDifferent(to: \.contextColor, on: self).store(in: &self.cancellables)
        viewModel.$progress.dropFirst().weakAssignIfDifferent(to: \.sessionProgress, on: self).store(in: &self.cancellables)

        viewModel.$imageURL.dropFirst().sink { [weak self] imageUrl in
            self?.loadSessionImage(at: imageUrl, for: viewModel.identifier)
        }
        .store(in: &self.cancellables)
    }

    @MainActor
    func loadSessionImage(at imageURL: URL?, for sessionIdentifier: String) {
        guard imageDownloadOperation?.url != imageURL else {
            // Already downloading this image
            return
        }

        if let imageDownloadOperation {
            imageDownloadOperation.task.cancel()
            self.imageDownloadOperation = nil
        }

        guard let imageURL else {
            self.thumbnailImage = nil
            return
        }

        let task = Task { [weak self] in
            let result = await ImageDownloadCenter.shared.downloadImage(from: imageURL, thumbnailHeight: Constants.thumbnailHeight, thumbnailOnly: true)
            guard let thumbnail = result.thumbnail else {
                return
            }

            guard sessionIdentifier == self?.viewModel?.session.identifier else {
                return
            }

            self?.thumbnailImage = thumbnail
        }

        self.imageDownloadOperation = DownloadOperation(url: imageURL, task: task)
    }

    struct DownloadOperation {
        let url: URL
        let task: Task<Void, Never>
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

            Image(nsImage: SessionCellViewModel.placeholderImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 85, height: 48)
                .drawingGroup()
                .overlay {
                    // Use an overlay for the real thumbnail, this avoids re-drawing the placeholder image during
                    // cell recycling in the table view. 🏎️
                    if let thumbnailImage = cellViewModel.thumbnailImage {
                        Image(nsImage: thumbnailImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 85, height: 48)
                            .drawingGroup()
                    }
                }
                .animation(cellViewModel.thumbnailImage == nil ? nil : .snappy.speed(2), value: cellViewModel.thumbnailImage)
                .clipShape(.rect(cornerRadius: 4))
                .padding(.horizontal, 8)

            informationLabels

            statusIcons
        }
        .padding(.leading, 10)
        .padding(.trailing, 4)
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
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .lineLimit(1)
        .truncationMode(.tail)
    }

    private var statusIcons: some View {
        // Icons
        VStack(spacing: 0) {
            Image(.starSmall)
                .resizable()
                .scaledToFit()
                .opacity(cellViewModel.isFavorite ? 1 : 0)

            Spacer()

            Image(systemName: "bookmark.fill")
                .resizable()
                .scaledToFit()
                .opacity(cellViewModel.hasBookmarks ? 1 : 0)

            Spacer()

            Image(.downloadSmall)
                .resizable()
                .scaledToFit()
                .opacity(cellViewModel.isDownloaded ? 1 : 0)
        }
        .frame(width: 12)
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
