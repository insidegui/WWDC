//
//  SessionItemViewModel.swift
//  WWDC
//
//  Created by luca on 07.08.2025.
//  Copyright © 2025 Guilherme Rambo. All rights reserved.
//

import Combine
import ConfCore
import SwiftUI

@Observable class SessionItemViewModel: Identifiable {
    var id: String { session.identifier }
    @ObservationIgnored let session: SessionViewModel
    @ObservationIgnored private var observers = Set<AnyCancellable>()
    @ObservationIgnored private(set) var coverImageURL: URL?
    @ObservationIgnored private weak var smallImageDownloadOperation: Operation?
    @ObservationIgnored private weak var fullImageDownloadOperation: Operation?

    var progress: Double = 0
    var isWatched: Bool {
        progress >= Constants.watchedVideoRelativePosition
    }

    var contextColor: NSColor = .clear
    var title = ""
    var subtitle = ""
    var summary = ""
    var footer = ""
    var context = ""
    var isFavorite = false
    var isDownloaded = false

    // MARK: - Cover Caches

    var smallCover: NSImage?
    var fullCover: NSImage?

    // MARK: - Actions

    var slidesButtonIsHidden: Bool = false
    var calendarButtonIsHidden: Bool = false
    var downloadState: SessionActionsViewModel.DownloadState = .notDownloadable

    var relatedSessions: [SessionItemViewModel] = []
    init(session: SessionViewModel) {
        self.session = session
    }

    func prepareForDisplay() {
        guard observers.isEmpty else { return }
        updateOverviewBindings()
        updateActionBindings()
    }
}

// MARK: - Overview

private extension SessionItemViewModel {
    func updateOverviewBindings() {
        session.rxProgresses.replaceErrorWithEmpty()
            .compactMap(\.first?.relativePosition)
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newValue in
                withAnimation {
                    self?.progress = newValue
                }
            }
            .store(in: &observers)
        session.rxColor.removeDuplicates()
            .replaceError(with: .clear)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newValue in
                withAnimation {
                    self?.contextColor = newValue
                }
            }
            .store(in: &observers)
        session.rxImageUrl.replaceErrorWithEmpty()
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newValue in
                self?.coverImageURL = newValue
            }
            .store(in: &observers)

        title = session.session.title
        session.rxTitle.replaceError(with: "")
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newValue in
                self?.title = newValue
            }
            .store(in: &observers)
        session.rxSubtitle.replaceError(with: "")
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newValue in
                withAnimation {
                    self?.subtitle = newValue
                }
            }
            .store(in: &observers)
        summary = session.session.summary
        session.rxSummary.replaceError(with: "")
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newValue in
                withAnimation {
                    self?.summary = newValue
                }
            }
            .store(in: &observers)
        session.rxFooter.replaceError(with: "")
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newValue in
                withAnimation {
                    self?.footer = newValue
                }
            }
            .store(in: &observers)
        session.rxContext.replaceError(with: "")
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newValue in
                withAnimation {
                    self?.context = newValue
                }
            }
            .store(in: &observers)

        isFavorite = session.session.isFavorite
        session.rxIsFavorite.replaceError(with: false)
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newValue in
                withAnimation {
                    self?.isFavorite = newValue
                }
            }
            .store(in: &observers)
        isDownloaded = session.session.isDownloaded
        session.rxIsDownloaded.replaceError(with: false)
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newValue in
                withAnimation {
                    self?.isDownloaded = newValue
                }
            }
            .store(in: &observers)
        session.rxRelatedSessions
            .replaceErrorWithEmpty()
            .map {
                $0.compactMap { $0.session.flatMap(SessionViewModel.init(session:))
                    .flatMap(SessionItemViewModel.init(session:))
                }
            }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newValue in
                withAnimation {
                    self?.relatedSessions = newValue.uniqueSessions()
                }
            }
            .store(in: &observers)
    }
}

private extension Array where Element == SessionItemViewModel {
    func uniqueSessions() -> [SessionItemViewModel] {
        var results: [SessionItemViewModel] = []
        for session in self {
            if !results.contains(where: { $0.id == session.id }) {
                results.append(session)
            }
        }
        return results
    }
}

// MARK: - Image Tasks

extension SessionItemViewModel {
    @ImageDownloadActor
    private func downloadCover(height: CGFloat, image: ReferenceWritableKeyPath<SessionItemViewModel, NSImage?>, operation: ReferenceWritableKeyPath<SessionItemViewModel, Operation?>) async {
        guard let url = coverImageURL else {
            return
        }
        self[keyPath: image] = ImageDownloadCenter.shared.cachedImage(from: url, thumbnailOnly: height <= Constants.thumbnailHeight)
        self[keyPath: operation]?.cancel()
        self[keyPath: operation] = nil
        self[keyPath: operation] = ImageDownloadCenter.shared.downloadImage(from: url, thumbnailHeight: height) { [weak self] _, result in
            self?[keyPath: image] = result.original
        }
    }

    func downloadSmallCoverIfNeeded() async {
        guard smallCover == nil else {
            return
        }
        await downloadCover(height: Constants.thumbnailHeight, image: \.smallCover, operation: \.smallImageDownloadOperation)
    }

    func downloadFullCoverIfNeeded() async {
        guard fullCover == nil else {
            return
        }
        await downloadCover(height: 400, image: \.fullCover, operation: \.fullImageDownloadOperation)
    }
}

// MARK: - Actions

private extension SessionItemViewModel {
    func updateActionBindings() {
        slidesButtonIsHidden = (session.session.asset(ofType: .slides) == nil)
        calendarButtonIsHidden = (session.sessionInstance.startTime < today())

        let downloadID = session.session.downloadIdentifier

        /// Initial state
//        DispatchQueue.main.async {
//            self.downloadState = SessionActionsViewModel.downloadState(
//                session: self.session.session,
//                downloadState: MediaDownloadManager.shared.downloads.first { $0.id == downloadID }?.state
//            )
//        }

        /// `true` if the session has already been downloaded.
        let alreadyDownloaded: AnyPublisher<Session, Never> = session.session
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
            .map(SessionActionsViewModel.downloadState(session:downloadState:))
            .sink { [weak self] newState in
                withAnimation {
                    self?.downloadState = newState
                }
            }
            .store(in: &observers)
    }
}

@available(macOS 26.0, *)
extension SessionItemViewModel {
    @MainActor func toggleFavorite() {
        coordinator?.sessionActionsDidSelectFavorite(nil)
    }

    @MainActor func showSlides() {
        coordinator?.sessionActionsDidSelectSlides(nil)
    }

    @MainActor func download() {
        coordinator?.sessionActionsDidSelectDownload(nil)
    }

    @MainActor func addCalendar() {
        coordinator?.sessionActionsDidSelectCalendar(nil)
    }

    @MainActor func deleteDownload() {
        coordinator?.sessionActionsDidSelectDeleteDownload(nil)
    }

    @MainActor func share() {
        coordinator?.sessionActionsDidSelectShare(nil)
    }

    @MainActor func shareClip() {
        coordinator?.sessionActionsDidSelectShareClip(nil)
    }

    @MainActor func cancelDownload() {
        coordinator?.sessionActionsDidSelectCancelDownload(nil)
    }
}

/// isolate ImageDownloadCenter caching to this actor
@globalActor
actor ImageDownloadActor {
    static let shared = ImageDownloadActor()
}
