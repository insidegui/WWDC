//
//  PlaybackViewModel.swift
//  WWDC
//
//  Created by Guilherme Rambo on 23/04/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Foundation
import ConfCore
import AVFoundation
import PlayerUI
import RxCocoa
import RxSwift

enum PlaybackError: Error {
    case sessionNotFound(String)
    case assetNotFound(String)
    case invalidAsset(String)

    var localizedDescription: String {
        switch self {
        case .sessionNotFound(let identifier):
            return "Unable to find session with identifier \(identifier)"
        case .assetNotFound(let identifier):
            return "Unable to find asset for session \(identifier)"
        case .invalidAsset(let url):
            return "Invalid stream: \(url)"
        }
    }
}

final class PlaybackViewModel {

    let sessionViewModel: SessionViewModel
    let player: AVPlayer
    let isLiveStream: Bool

    var remoteMediaURL: URL?
    var title: String?
    var imageURL: URL?
    var image: NSImage?

    private let storage: Storage

    private var timeObserver: Any?

    var nowPlayingInfo: BehaviorRelay<PUINowPlayingInfo?> = BehaviorRelay(value: nil)

    init(sessionViewModel: SessionViewModel, storage: Storage) throws {
        self.storage = storage
        title = sessionViewModel.title
        imageURL = sessionViewModel.imageUrl

        self.sessionViewModel = sessionViewModel
        remoteMediaURL = nil

        guard let session = storage.session(with: sessionViewModel.identifier) else {
            throw PlaybackError.sessionNotFound(sessionViewModel.identifier)
        }

        var streamUrl: URL?

        // first, check if the session is being live streamed now
        if session.instances.filter("isCurrentlyLive == true").count > 0 {
            if let liveURL = session.asset(ofType: .liveStreamVideo).map({ URL(string: $0.remoteURL) }) {
                streamUrl = liveURL
                remoteMediaURL = liveURL
                isLiveStream = true
            } else {
                isLiveStream = false
            }
        } else {
            isLiveStream = false
        }

        // not live
        if !isLiveStream {
            // must have at least streaming video asset
            guard let asset = session.asset(ofType: .streamingVideo) else {
                throw PlaybackError.assetNotFound(session.identifier)
            }

            // remote url for the streaming video must be valid
            guard let remoteUrl = URL(string: asset.remoteURL) else {
                throw PlaybackError.invalidAsset(asset.remoteURL)
            }

            remoteMediaURL = remoteUrl

            // check if we have a downloaded file and use it instead
            if let localUrl = DownloadManager.shared.downloadedFileURL(for: session) {
                streamUrl = localUrl
            } else {
                streamUrl = remoteUrl
            }
        }

        guard var finalUrl = streamUrl else {
            throw PlaybackError.invalidAsset("No valid video URL could be found")
        }

        #if DEBUG
            if Arguments.useTestVideo {
                finalUrl = URL(fileURLWithPath: "/Users/inside/Movies/test.m4v")
            }
        #endif

        player = AVPlayer(url: finalUrl)
        nowPlayingInfo.accept(PUINowPlayingInfo(playbackViewModel: self))

        initializePlayerTimeSyncIfNeeded(with: session)
    }

    private let progressQueue = DispatchQueue(label: "Progress", qos: .background)

    private func initializePlayerTimeSyncIfNeeded(with session: Session) {
        guard !isLiveStream else { return }

        if session.isWatched || session.currentPosition().isZero {
            if Preferences.shared.skipIntro {
                player.seek(to: CMTimeMakeWithSeconds(Float64(session.firstAnnotationTime), preferredTimescale: 1), toleranceBefore: .zero, toleranceAfter: .zero)
            } else {
                player.seek(to: CMTimeMakeWithSeconds(0, preferredTimescale: 9000))
            }
        } else {
            player.seek(to: CMTimeMakeWithSeconds(Float64(session.currentPosition()), preferredTimescale: 9000))
        }

        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTimeMakeWithSeconds(15, preferredTimescale: 9000), queue: progressQueue) { [weak self] currentTime in
            guard let self = self else { return }

            guard let duration = self.player.currentItem?.asset.durationIfLoaded else { return }

            guard CMTIME_IS_VALID(duration) else { return }

            let p = Double(CMTimeGetSeconds(currentTime))
            let d = Double(CMTimeGetSeconds(duration))

            Session.setCurrentPosition(
                for: self.sessionViewModel.sessionIdentifier,
                in: self.storage,
                position: p,
                duration: d
            )

            if !d.isZero {
                DispatchQueue.main.async {
                    if var nowPlayingInfo = self.nowPlayingInfo.value {
                        nowPlayingInfo.progress = p / d
                        self.nowPlayingInfo.accept(nowPlayingInfo)
                    }
                }
            }
        }
    }

    deinit {
        if let timeObserver = timeObserver {
            player.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }
    }

}

extension PUINowPlayingInfo {

    init(playbackViewModel: PlaybackViewModel) {
        let title = playbackViewModel.title ?? "WWDC Session"
        let eventName = playbackViewModel.sessionViewModel.session.event.first?.name ?? "WWDC"

        self = PUINowPlayingInfo(
            title: title,
            artist: eventName,
            progress: 0,
            isLive: playbackViewModel.isLiveStream,
            image: playbackViewModel.image
        )
    }

}

extension Session {
    var firstAnnotationTime: Double {
        transcript()?.annotations.first?.timecode ?? 0
    }
}
