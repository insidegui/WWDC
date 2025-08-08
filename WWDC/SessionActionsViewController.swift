//
//  SessionActionsViewController.swift
//  WWDC
//
//  Created by Guilherme Rambo on 06/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import SwiftUI
import PlayerUI
import ConfCore
import Combine

@MainActor
protocol SessionActionsDelegate: AnyObject {
    func sessionActionsDidSelectSlides(_ sender: NSView?)
    func sessionActionsDidSelectFavorite(_ sender: NSView?)
    func sessionActionsDidSelectDownload(_ sender: NSView?)
    func sessionActionsDidSelectCalendar(_ sender: NSView?)
    func sessionActionsDidSelectDeleteDownload(_ sender: NSView?)
    func sessionActionsDidSelectCancelDownload(_ sender: NSView?)
    func sessionActionsDidSelectShare(_ sender: NSView?)
    func sessionActionsDidSelectShareClip(_ sender: NSView?)
}

final class SessionActionsViewModel: ObservableObject {
    @Published var viewModel: SessionViewModel? {
        didSet {
            DispatchQueue.main.async {
                self.updateBindings()
            }
        }
    }

    weak var delegate: SessionActionsDelegate?

    private var cancellables: Set<AnyCancellable> = []

    @Published var slidesButtonIsHidden: Bool = false
    @Published var calendarButtonIsHidden: Bool = false
    @Published var downloadState: DownloadState = .notDownloadable
    @Published var isFavorited = false

    init(session: SessionViewModel? = nil) {
        self.viewModel = session
        DispatchQueue.main.async {
            self.updateBindings()
        }
    }

    enum DownloadState: Equatable {
        case notDownloadable
        case downloadable
        case pending
        case downloading(progress: Double)
        case downloaded

        var isDownloading: Bool {
            if case .downloading = self { true } else { false }
        }

        var isPending: Bool {
            if case .pending = self { true } else { false }
        }

        var showsButton: Bool {
            switch self {
            case .downloadable, .downloaded: true
            case .notDownloadable, .pending, .downloading: false
            }
        }

        var showsInlineButton: Bool {
            switch self {
            case .downloadable, .downloaded, .pending, .downloading: true
            case .notDownloadable: false
            }
        }

        var allocatesSpace: Bool {
            switch self {
            case .downloadable, .pending, .downloading, .downloaded: true
            case .notDownloadable: false
            }
        }

        var downloadProgress: Double? {
            if case .downloading(let progress) = self { progress } else { nil }
        }
    }

    @MainActor private func updateBindings() {
        cancellables = []

        guard let viewModel = viewModel else { return }

        slidesButtonIsHidden = (viewModel.session.asset(ofType: .slides) == nil)
        calendarButtonIsHidden = (viewModel.sessionInstance.startTime < today())

        isFavorited = viewModel.session.isFavorite
        viewModel.rxIsFavorite.replaceError(with: false).assign(to: \.isFavorited, on: self).store(in: &cancellables)

        let downloadID = viewModel.session.downloadIdentifier

        /// Initial state
        downloadState = Self.downloadState(
            session: viewModel.session,
            downloadState: MediaDownloadManager.shared.downloads.first { $0.id == downloadID }?.state
        )

        /// `true` if the session has already been downloaded.
        let alreadyDownloaded: AnyPublisher<Session, Never> = viewModel.session
            .valuePublisher(keyPaths: ["isDownloaded"])
            .replaceErrorWithEmpty()
            .eraseToAnyPublisher()

        /// Emits subscribes to the downloads and then if 1 is added that matches our session, subscribes to the state of that download
        let downloadStateSignal: AnyPublisher<MediaDownloadState?, Never> = MediaDownloadManager.shared.$downloads
            .map { $0.first(where: { $0.id == downloadID }) }
            .removeDuplicates()
            .map { download in
                guard let download else {
                    // no download -> no state
                    return Just<MediaDownloadState?>(nil).eraseToAnyPublisher()
                }

                return download.$state.map(Optional.some).eraseToAnyPublisher()
            }
            .switchToLatest()
            .eraseToAnyPublisher()

        /// Combined stream that emits whenever any relevant state changes
        Publishers.CombineLatest(alreadyDownloaded, downloadStateSignal)
            .map(Self.downloadState(session:downloadState:))
            .sink { [weak self] newState in
                self?.downloadState = newState
            }
            .store(in: &cancellables)
    }

    /// There is a small gap in the logic here. Because the download manager will have a completed task before
    /// Realm writes and then publishes the new `isDownloaded` state.
    ///
    /// This means the button will show the download button briefly before switching to the delete button.
    static func downloadState(session: Session, downloadState: MediaDownloadState?) -> DownloadState {
        if let downloadState {
            switch downloadState {
            case .waiting:
                return .pending
            case .downloading(let progress):
                return .downloading(progress: progress)
            case .paused(let progress):
                return .downloading(progress: progress)
            case .failed, .cancelled:
                return .downloadable
            case .completed:
                // Even if completed, we still need to verify it exists on disk
                // because the user may have deleted the file after download
                // Fall through to filesystem check below
                break
            }
        }

        // Only check filesystem when there's no active download (or download completed)
        if session.isDownloaded, MediaDownloadManager.shared.hasDownloadedMedia(for: session) {
            return .downloaded
        }

        // Check if content is downloadable
        guard !session.assets(matching: Session.mediaDownloadVariants).isEmpty else {
            return .notDownloadable
        }

        return .downloadable
    }

    @MainActor func toggleFavorite() {
        delegate?.sessionActionsDidSelectFavorite(nil)
    }

    @MainActor func showSlides() {
        delegate?.sessionActionsDidSelectSlides(nil)
    }

    @MainActor func download() {
        delegate?.sessionActionsDidSelectDownload(nil)
    }

    @MainActor func addCalendar() {
        delegate?.sessionActionsDidSelectCalendar(nil)
    }

    @MainActor func deleteDownload() {
        delegate?.sessionActionsDidSelectDeleteDownload(nil)
    }

    @MainActor func share() {
        delegate?.sessionActionsDidSelectShare(nil)
    }

    @MainActor func shareClip() {
        delegate?.sessionActionsDidSelectShareClip(nil)
    }

    @MainActor func cancelDownload() {
        delegate?.sessionActionsDidSelectCancelDownload(nil)
    }
}
