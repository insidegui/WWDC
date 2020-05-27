//
//  TranscriptDownloader.swift
//  Transcripts
//
//  Created by Guilherme Rambo on 25/05/20.
//  Copyright © 2020 Guilherme Rambo. All rights reserved.
//

import Foundation
import os.log

public final class TranscriptDownloader {

    private let log = OSLog(subsystem: Transcripts.subsystemName, category: String(describing: TranscriptDownloader.self))

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
        os_log("%{public}@", log: log, type: .debug, #function)

        transcriptCountLoaded = 0

        self.validSessionIdentifiers = validSessionIdentifiers
        self.progressHandler = progress
        self.completionHandler = completion

        fetchManifest()
    }

    private func callCompletion() {
        os_log("COMPLETED", log: self.log, type: .default)

        if !failedTranscriptIdentifiers.isEmpty {
            os_log("Failed transcript IDs: %@", log: self.log, type: .default, failedTranscriptIdentifiers.joined(separator: ", "))
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

            os_log("Handing out %d transcript(s) for storage", log: self.log, type: .debug, coalescedContents.count)

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

                os_log("Transcript manifest downloaded. %d transcripts available.", log: self.log, type: .debug, manifest.individual.count)

                self.processManifest(manifest)
            case .failure(let error):
                os_log("Error downloading transcript manifest: %{public}@", log: self.log, type: .error, String(describing: error))

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
            os_log("Ignoring %@ on manifest: not a session we know about. Maybe next time...", log: self.log, type: .debug, identifier)

            return false
        } else {
            return true
        }
    }

    private func processManifest(_ manifest: TranscriptManifest) {
        let validFeeds = manifest.individual.filter({ shouldDownload(with: $0.key) })

        transcriptCountToLoad = validFeeds.count
        transcriptCountLoaded = 0

        validFeeds.forEach { feed in
            downloadTranscriptIfNeeded(identifier: feed.key, url: feed.value.url, etag: feed.value.etag)
        }
    }

    private func downloadTranscriptIfNeeded(identifier: String, url: URL, etag: String) {
        if let previousEtag = storage.previousEtag(for: identifier) {
            guard etag != previousEtag else {
                os_log("Cached transcript %@ still valid, skipping download", log: self.log, type: .debug, identifier)
                transcriptCountLoaded += 1
                return
            }
        } else {
            os_log("No previous etag for %@, assuming new and downloading", log: self.log, type: .debug, identifier)
        }

        loader.load(from: url, decoder: { try JSONDecoder().decode(TranscriptContent.self, from: $0) }) { [weak self] result in
            guard let self = self else { return }

            defer { self.queue.async { self.transcriptCountLoaded += 1 } }

            switch result {
            case .success(let content):
                os_log("Downloaded %@", log: self.log, type: .debug, identifier)
                self.queue.async { self.store(content) }
            case .failure(let error):
                self.queue.async { self.failedTranscriptIdentifiers.append(identifier) }

                os_log("Failed to download %@: %{public}@", log: self.log, type: .error, identifier, String(describing: error))
            }
        }
    }

}
