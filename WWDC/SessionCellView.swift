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
    @Published var thumbnailImage: NSImage?

    @Published private var sessionProgress: SessionProgress?
    var progress: Double { sessionProgress.flatMap(\.relativePosition) ?? 1 }

    var isWatched: Bool {
        sessionProgress != nil && progress >= Constants.watchedVideoRelativePosition
    }
    
    private var cancellables: Set<AnyCancellable> = []
    private var imageDownloadOperation: DownloadOperation?

    static let placeholderImage = NSImage(resource: .noimage)

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

        // Current state
        self.title = viewModel.title
        self.subtitle = viewModel.subtitle
        self.context = viewModel.context
        self.isFavorite = viewModel.isFavorite
        self.isDownloaded = viewModel.isDownloaded
        self.contextColor = viewModel.color ?? .clear
        self.sessionProgress = viewModel.progress

        loadImage(url: viewModel.imageURL, sessionIdentifier: viewModel.identifier)

        // Future state
        deferredBind(viewModel)
    }

    /// Deferred binding is a performance optimization for the session list. When scrolling the list, we want cells to appear quickly using the current state
    /// and if the user settles on the sessions being visible, only then will it connect to the publisher. This is because of Realm's object notifications, which are
    /// very expensive to start listening to. We don't need to listen to them immediately and if the session gets scrolled out of view, the immediate binding
    /// ends up causes a hang.
    func deferredBind(_ viewModel: SessionViewModel) {
        // While it might seem like we can do `.assign(to: &$title)`, we actually can't because
        // both SessionViewModel and SessionCellViewModel are long lived items.
        //
        // SessionCellViewModel is recycled, so when a new SessionViewModel is attached, we need to break the
        // bindings with the previous one. Which means we MUST have a cancellables for as long as this is the architecture we have

        // There are 2 performance related things to note here:
        //
        // 1. Realm has an interesting bug with regard to object notifications that. If they're short-lived and created while in ``RunLoopMode.tracking``,
        //    they will be enqueued for processing once the run loop returns to the default mode. When the notifications are cancelled, they are not dequeued, which
        //    means if you're scrolling the list quickly, once you stop scrolling there will be a hang. Ideally, I'd get realm to fix this, but for now we can
        //    essentially just insert a delay.
        //
        // 2. ``ImageDownloadCenter.downloadImage()`` retrieves the cached value (from disk) on the calling thread, which means you should call it from
        //     a background thread to avoid blocking I/O on the UI thread. Ideally, ImageDownloadCenter should be updated to use a background
        //     thread for this, but for now we can shift to a background thread on our own.

        let doBind = { [weak self] in
            guard let self = self else { return }
            let sessionIdentifier = viewModel.session.identifier

            viewModel.$title.removeDuplicates().weakAssignIfDifferent(to: \.title, on: self).store(in: &self.cancellables)
            viewModel.$subtitle.removeDuplicates().weakAssignIfDifferent(to: \.subtitle, on: self).store(in: &self.cancellables)
            viewModel.rxContext.replaceError(with: "").weakAssignIfDifferent(to: \.context, on: self).store(in: &self.cancellables)
            viewModel.rxIsFavorite.replaceError(with: false).weakAssignIfDifferent(to: \.isFavorite, on: self).store(in: &self.cancellables)
            viewModel.$isDownloaded.removeDuplicates().weakAssignIfDifferent(to: \.isDownloaded, on: self).store(in: &self.cancellables)
            viewModel.$color.removeDuplicates().map { $0 ?? .clear }.weakAssignIfDifferent(to: \.contextColor, on: self).store(in: &self.cancellables)
            viewModel.rxProgresses.replaceErrorWithEmpty().map(\.first).weakAssignIfDifferent(to: \.sessionProgress, on: self).store(in: &self.cancellables)

            viewModel.$imageURL.removeDuplicates().sink { [weak self] imageUrl in
                self?.loadImage(url: imageUrl, sessionIdentifier: sessionIdentifier)
            }
            .store(in: &self.cancellables)
        }

        //        if RunLoop.main.currentMode == RunLoop.Mode.eventTracking {
        //            debugPrint("Tracking")
        let bindTask = Task { @MainActor in
            guard !Task.isCancelled else {
                debugPrint("Cancelled")
                return
            }

            do {
                try await Task.sleep(for: .milliseconds(100))
            } catch is CancellationError {
                debugPrint("Cancelled while waiting")
                return
            }

            doBind()
        }

        cancellables.insert(AnyCancellable { bindTask.cancel() })
        //        } else {
        //            doBind()
        //        }
    }

    func loadImage(url imageURL: URL?, sessionIdentifier: String) {
        guard imageDownloadOperation?.url != imageURL else {
            // Already downloading this image
            debugPrint("\(sessionIdentifier): Already downloading")
            return
        }

        if let imageDownloadOperation {
            debugPrint("\(sessionIdentifier): Cancelling existing task")
            imageDownloadOperation.task.cancel()
            self.imageDownloadOperation = nil
        }

        guard let imageURL else {
            self.thumbnailImage = nil
            debugPrint("\(sessionIdentifier): No image URL")
            return
        }

        debugPrint("\(sessionIdentifier): Begin image fetch")

        let task = Task.detached(priority: .low) { [weak self] in
            let (url, result) = await ImageDownloadCenter.shared.downloadImage(from: imageURL, thumbnailHeight: Constants.thumbnailHeight, thumbnailOnly: true)
            guard url == imageURL, let thumbnail = result.thumbnail, !Task.isCancelled else {
                debugPrint("\(sessionIdentifier): Nothing returned or cancelled")
                return
            }

            Task { @MainActor in
                guard sessionIdentifier == self?.viewModel?.session.identifier, !Task.isCancelled else {
                    debugPrint("\(sessionIdentifier): Session changed while downloading image, ignoring")
                    return
                }

                self?.thumbnailImage = thumbnail
            }
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
                .animation(cellViewModel.thumbnailImage == nil ? nil : .snappy, value: cellViewModel.thumbnailImage)
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
