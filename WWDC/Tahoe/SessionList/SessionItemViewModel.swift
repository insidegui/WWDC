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
    var id: String { session?.identifier ?? "" }
    var session: SessionViewModel? {
        didSet {
            if session?.identifier != oldValue?.identifier {
                prepareForDisplay()
            }
        }
    }

    @ObservationIgnored private var observers = Set<AnyCancellable>()

    var progress: Double = 0
    var isWatched: Bool {
        progress >= Constants.watchedVideoRelativePosition
    }

    var contextColor: NSColor = .clear
    var title = ""
    var subtitle = ""
    var coverImageURL: URL?
    var summary = ""
    var footer = ""
    var context = ""
    var isFavorite = false
    var isDownloaded = false

    var isMediaAvailable: Bool = false
    var isPlaying = false

    var isTranscriptAvailable: Bool = false

    // MARK: - Actions

    var slidesButtonIsHidden: Bool = false
    var calendarButtonIsHidden: Bool = false
    var downloadState: SessionActionsViewModel.DownloadState = .notDownloadable

    var relatedSessions: [SessionViewModel] = []
    init(session: SessionViewModel? = nil) {
        self.session = session
    }

    func prepareForDisplay() {
        observers = []
        updateOverviewBindings()
        updateActionBindings()
    }
}

// MARK: - Overview

private extension SessionItemViewModel {
    func updateOverviewBindings() {
        guard let session else {
            return
        }
        session.rxProgresses.replaceErrorWithEmpty()
            .compactMap(\.first?.relativePosition)
            .removeDuplicates()
            .sink { [weak self] newValue in
                withAnimation {
                    self?.progress = newValue
                }
            }
            .store(in: &observers)
        session.rxColor.removeDuplicates()
            .replaceError(with: .clear)
            .sink { [weak self] newValue in
                withAnimation {
                    self?.contextColor = newValue
                }
            }
            .store(in: &observers)
        session.rxImageUrl.replaceErrorWithEmpty()
            .removeDuplicates()
            .sink { [weak self] newValue in
                self?.coverImageURL = newValue
            }
            .store(in: &observers)

        title = session.session.title
        session.rxTitle.replaceError(with: "")
            .removeDuplicates()
            .sink { [weak self] newValue in
                self?.title = newValue
            }
            .store(in: &observers)
        session.rxSubtitle.replaceError(with: "")
            .removeDuplicates()
            .sink { [weak self] newValue in
                withAnimation {
                    self?.subtitle = newValue
                }
            }
            .store(in: &observers)
        summary = session.session.summary
        session.rxSummary.replaceError(with: "")
            .removeDuplicates()
            .sink { [weak self] newValue in
                withAnimation {
                    self?.summary = newValue
                }
            }
            .store(in: &observers)
        session.rxFooter.replaceError(with: "")
            .removeDuplicates()
            .sink { [weak self] newValue in
                withAnimation {
                    self?.footer = newValue
                }
            }
            .store(in: &observers)
        session.rxContext.replaceError(with: "")
            .removeDuplicates()
            .sink { [weak self] newValue in
                withAnimation {
                    self?.context = newValue
                }
            }
            .store(in: &observers)

        isFavorite = session.session.isFavorite
        session.rxIsFavorite.replaceError(with: false)
            .removeDuplicates()
            .sink { [weak self] newValue in
                withAnimation {
                    self?.isFavorite = newValue
                }
            }
            .store(in: &observers)
        isDownloaded = session.session.isDownloaded
        session.rxIsDownloaded.replaceError(with: false)
            .removeDuplicates()
            .sink { [weak self] newValue in
                withAnimation {
                    self?.isDownloaded = newValue
                }
            }
            .store(in: &observers)
        session.rxRelatedSessions
            .replaceErrorWithEmpty()
            .map {
                $0.compactMap {
                    $0.session.flatMap(SessionViewModel.init(session:))
                }
            }
            .sink { [weak self] newValue in
                withAnimation {
                    self?.relatedSessions = newValue.uniqueSessions()
                }
            }
            .store(in: &observers)
        session.rxTranscript
            .replaceError(with: nil)
            .map {  $0 != nil }
            .sink { [weak self] newValue in
                self?.isTranscriptAvailable = newValue
            }
            .store(in: &observers)
        session.rxCanBePlayed
            .replaceError(with: false)
            .sink { [weak self] newValue in
                self?.isMediaAvailable = newValue
            }
            .store(in: &observers)
    }
}

private extension Array where Element == SessionViewModel {
    func uniqueSessions() -> [SessionViewModel] {
        var results: [SessionViewModel] = []
        for session in self {
            if !results.contains(where: { $0.identifier == session.identifier }) {
                results.append(session)
            }
        }
        return results
    }
}

// MARK: - Actions

private extension SessionItemViewModel {
    func updateActionBindings() {
        guard let session else {
            return
        }
        slidesButtonIsHidden = (session.session.asset(ofType: .slides) == nil)
        calendarButtonIsHidden = (session.sessionInstance.startTime < today())

        let downloadID = session.session.downloadIdentifier

        /// Initial state
        DispatchQueue.main.async {
            self.downloadState = SessionActionsViewModel.downloadState(
                session: session.session,
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
