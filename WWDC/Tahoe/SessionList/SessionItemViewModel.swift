//
//  SessionItemViewModel.swift
//  WWDC
//
//  Created by luca on 07.08.2025.
//  Copyright © 2025 Guilherme Rambo. All rights reserved.
//

import SwiftUI
import Combine

@Observable class SessionItemViewModel {
    @ObservationIgnored private let session: SessionViewModel
    @ObservationIgnored private var observers = Set<AnyCancellable>()

    var progress: Double = 0
    var isWatched: Bool {
        progress >= Constants.watchedVideoRelativePosition
    }

    var contextColor: NSColor = .clear
    var thumbnailURL: URL?
    var title = ""
    var subtitle = ""
    var context = ""
    var isFavorite = false
    var isDownloaded = false
    init(session: SessionViewModel) {
        self.session = session
    }

    func prepareForDisplay() {
        session.rxProgresses.replaceErrorWithEmpty()
            .compactMap(\.first?.relativePosition)
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.progress = $0
            }
            .store(in: &observers)
        session.rxColor.removeDuplicates()
            .replaceError(with: .clear)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.contextColor = $0
            }
            .store(in: &observers)
        session.rxImageUrl.replaceErrorWithEmpty()
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.thumbnailURL = $0
            }
            .store(in: &observers)

        session.rxTitle.replaceError(with: "")
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.title = $0
            }
            .store(in: &observers)
        session.rxSubtitle.replaceError(with: "")
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.subtitle = $0
            }
            .store(in: &observers)
        session.rxContext.replaceError(with: "")
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.context = $0
            }
            .store(in: &observers)
        session.rxIsFavorite.replaceError(with: false)
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.isFavorite = $0
            }
            .store(in: &observers)
        session.rxIsDownloaded.replaceError(with: false)
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.isDownloaded = $0
            }
            .store(in: &observers)
    }

    func prepareForDistory() {
        observers.removeAll()
    }
}
