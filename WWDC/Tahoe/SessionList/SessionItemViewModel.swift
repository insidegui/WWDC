//
//  SessionItemViewModel.swift
//  WWDC
//
//  Created by luca on 07.08.2025.
//  Copyright © 2025 Guilherme Rambo. All rights reserved.
//

import SwiftUI
import Combine
import ConfCore

@Observable class SessionItemViewModel: Identifiable {
    var id: String { session.identifier }
    @ObservationIgnored let session: SessionViewModel
    @ObservationIgnored private var observers = Set<AnyCancellable>()

    var progress: Double = 0
    var isWatched: Bool {
        progress >= Constants.watchedVideoRelativePosition
    }

    var contextColor: NSColor = .clear
    var thumbnailURL: URL?
    var title = ""
    var subtitle = ""
    var summary = ""
    var footer = ""
    var context = ""
    var isFavorite = false
    var isDownloaded = false

    // MARK: - Actions

    var slidesButtonIsHidden: Bool = false
    var calendarButtonIsHidden: Bool = false
    var downloadState: SessionActionsViewModel.DownloadState = .notDownloadable

    init(session: SessionViewModel) {
        self.session = session
    }

    func prepareForDisplay() {
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
                self?.thumbnailURL = newValue
            }
            .store(in: &observers)

        session.rxTitle.replaceError(with: "")
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newValue in
                withAnimation {
                    self?.title = newValue
                }
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
        session.rxIsDownloaded.replaceError(with: false)
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newValue in
                withAnimation {
                    self?.isDownloaded = newValue
                }
            }
            .store(in: &observers)
    }
}
// MARK: - Actions

private extension SessionItemViewModel {
    func updateActionBindings() {
        slidesButtonIsHidden = (session.session.asset(ofType: .slides) == nil)
        calendarButtonIsHidden = (session.sessionInstance.startTime < today())

        let downloadID = session.session.downloadIdentifier

        /// Initial state
        DispatchQueue.main.async {
            self.downloadState = SessionActionsViewModel.downloadState(
                session: self.session.session,
                downloadState: MediaDownloadManager.shared.downloads.first { $0.id == downloadID }?.state
            )
        }

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
