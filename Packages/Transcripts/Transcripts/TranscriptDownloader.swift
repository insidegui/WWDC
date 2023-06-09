//
//  TranscriptDownloader.swift
//  Transcripts
//
//  Created by Guilherme Rambo on 25/05/20.
//  Copyright © 2020 Guilherme Rambo. All rights reserved.
//

import Foundation
import OSLog

public final class TranscriptDownloader {

    private let log = Logger(subsystem: Transcripts.subsystemName, category: String(describing: TranscriptDownloader.self))

    let loader: Loader
    let manifestURL: URL
    let storage: TranscriptStorage
    let queue: DispatchQueue
    let storageCoalescingInterval: TimeInterval

    public init(loader: Loader = URLSessionLoader(),
                manifestURL: URL,
                storage: TranscriptStorage,
                queue: DispatchQueue = .main,
                storageCoalescingInterval: TimeInterval = 1) {
        self.loader = loader
        self.manifestURL = manifestURL
        self.storage = storage
        self.queue = queue
        self.storageCoalescingInterval = storageCoalescingInterval
    }

    public typealias ProgressHandler = (Float) -> Void
    public typealias CompletionHandler = () -> Void

    private var progressHandler: ProgressHandler?
    private var completionHandler: CompletionHandler?
    private var validSessionIdentifiers: [String]?

    public func fetch(validSessionIdentifiers: [String]? = nil, progress: @escaping ProgressHandler, completion: @escaping CompletionHandler) {
        log.debug(#function)

        transcriptCountLoaded = 0

        self.validSessionIdentifiers = validSessionIdentifiers
        self.progressHandler = progress
        self.completionHandler = completion

        fetchManifest()
    }

    private func callCompletion() {
        log.debug("COMPLETED")

        if !failedTranscriptIdentifiers.isEmpty {
            log.debug("Failed transcript IDs: \(self.failedTranscriptIdentifiers.joined(separator: ", "), privacy: .public)")
        }

        queue.async { [weak self] in
            self?.completionHandler?()
        }
    }

    private func callProgress(_ progress: Float) {
        queue.async { [weak self] in
            self?.progressHandler?(progress)
        }
    }

    private lazy var coalescer: Coalescer<TranscriptContent> = {
        Coalescer(delay: self.storageCoalescingInterval)
    }()

    private func store(_ contents: TranscriptContent) {
        guard let manifest = currentManifest else {
            preconditionFailure("store called before the manifest was available!")
        }

        coalescer.run(for: [contents], queue: queue) { [weak self] coalescedContents in
            guard let self = self else { return }

            self.log.debug("Handing out \(coalescedContents.count) transcript(s) for storage")

            self.storage.store(coalescedContents, manifest: manifest)
        }
    }

    private var currentManifest: TranscriptManifest?

    private func fetchManifest() {
        loader.load(from: manifestURL, decoder: { try JSONDecoder().decode(TranscriptManifest.self, from: $0) }) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let manifest):
                self.currentManifest = manifest

                self.log.debug("Transcript manifest downloaded. \(manifest.individual.count) transcripts available.")

                self.processManifest(manifest)
            case .failure(let error):
                self.log.error("Error downloading transcript manifest: \(String(describing: error), privacy: .public)")

                self.callCompletion()
            }
        }
    }

    private(set) var failedTranscriptIdentifiers: [String] = []

    private var transcriptCountToLoad = 0

    private var transcriptCountLoaded = 0 {
        didSet {
            guard transcriptCountLoaded != oldValue else { return }

            callProgress(Float(transcriptCountLoaded)/Float(transcriptCountToLoad))

            if transcriptCountLoaded == transcriptCountToLoad { callCompletion() }
        }
    }

    private func shouldDownload(with identifier: String) -> Bool {
        guard let validIdentifiers = validSessionIdentifiers else { return true }

        if !validIdentifiers.contains(identifier) {
            self.log.debug("Ignoring \(identifier, privacy: .public) on manifest: not a session we know about. Maybe next time...")

            return false
        } else {
            return true
        }
    }

    private func processManifest(_ manifest: TranscriptManifest) {
        let validFeeds = manifest.individual.filter({ shouldDownload(with: $0.key) })

        transcriptCountToLoad = validFeeds.count
        transcriptCountLoaded = 0

        let transcripts: [(identifier: String, url: URL, status: CacheStatus)] = validFeeds.map { feed in
            let identifier = feed.key
            return (identifier: identifier, url: feed.value.url, status: cacheStatus(identifier: identifier, etag: feed.value.etag))
        }

        let transcriptsByStatus = Dictionary(grouping: transcripts, by: \.status)
        let cached = transcriptsByStatus[.match, default: []]
        let mismatched = transcriptsByStatus[.etagMismatch, default: []]
        let noPreviousEtag = transcriptsByStatus[.noPreviousEtag, default: []]

        let cachedEtagMessage = cached.count == 0 ? "none" : cached.map(\.identifier).joined(separator: ", ")
        let mismatchedMessage = mismatched.count == 0 ? "none" : mismatched.map(\.identifier).joined(separator: ", ")
        let noPreviousEtagMessage = noPreviousEtag.count == 0 ? "none" : noPreviousEtag.map(\.identifier).joined(separator: ", ")

        log.trace(
            """
            Transcript Status:
            \tCached:          \(cachedEtagMessage)
            \tMissing etag:    \(noPreviousEtagMessage)
            \tMismatched etag: \(mismatchedMessage)
            """
        )

        transcriptCountLoaded += cached.count

        (mismatched + noPreviousEtag).forEach { (identifier, url, _) in
            downloadTranscript(identifier: identifier, url: url)
        }
    }

    enum CacheStatus {
        case etagMismatch, noPreviousEtag, match
    }

    private func cacheStatus(identifier: String, etag: String) -> CacheStatus {
        guard let previousEtag = storage.previousEtag(for: identifier) else {
            return .noPreviousEtag
        }

        return etag == previousEtag ? .match : .etagMismatch
    }

    private func downloadTranscript(identifier: String, url: URL) {
        loader.load(from: url, decoder: { try JSONDecoder().decode(TranscriptContent.self, from: $0) }) { [weak self] result in
            guard let self = self else { return }

            defer { self.queue.async { self.transcriptCountLoaded += 1 } }

            switch result {
            case .success(let content):
                self.log.debug("Downloaded \(identifier, privacy: .public)")
                self.queue.async { self.store(content) }
            case .failure(let error):
                self.queue.async { self.failedTranscriptIdentifiers.append(identifier) }

                self.log.error("Failed to download \(identifier, privacy: .public): \(String(describing: error), privacy: .public)")
            }
        }
    }

}
