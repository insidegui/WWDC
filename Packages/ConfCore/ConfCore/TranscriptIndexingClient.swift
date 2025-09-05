//
//  TranscriptIndexingClient.swift
//  ConfCore
//
//  Created by Guilherme Rambo on 27/05/20.
//  Copyright © 2020 Guilherme Rambo. All rights reserved.
//

import Foundation

@MainActor
final class TranscriptIndexingClient: NSObject, TranscriptIndexingClientProtocol, Logging {

    static let log = makeLogger()

    var transcriptLanguage: String {
        didSet {
            guard transcriptLanguage != oldValue else { return }

            didRunService = false
            startIndexing(ignoringCache: true)
        }
    }

    private let storage: Storage
    private let appleClient: AppleAPIClient

    @MainActor
    init(language: String, storage: Storage, appleClient: AppleAPIClient = AppleAPIClient(environment: .current)) {
        self.transcriptLanguage = language
        self.storage = storage
        self.appleClient = appleClient

        super.init()

        transcriptIndexingConnection.resume()
    }

    @Published private(set) var isIndexing = false
    @Published private(set) var indexingProgress: Float = 0

    private var didRunService = false

    private lazy var transcriptIndexingConnection: NSXPCConnection = {
        let c = NSXPCConnection(serviceName: "io.wwdc.app.TranscriptIndexingService")

        c.remoteObjectInterface = NSXPCInterface(with: TranscriptIndexingServiceProtocol.self)
        c.exportedInterface = NSXPCInterface(with: TranscriptIndexingClientProtocol.self)
        c.exportedObject = self

        return c
    }()

    private var transcriptIndexingService: TranscriptIndexingServiceProtocol? {
        return transcriptIndexingConnection.remoteObjectProxyWithErrorHandler { [weak self] error in
            guard let self = self else { return }
            log.fault("Failed to get remote object proxy: \(String(describing: error), privacy: .public)")
        } as? TranscriptIndexingServiceProtocol
    }

    private var migratedTranscriptsToNativeVersion: Bool {
        get { UserDefaults.standard.bool(forKey: #function) }
        set { UserDefaults.standard.set(newValue, forKey: #function) }
    }

    func startIndexing(ignoringCache ignoreCache: Bool) {
        guard !ProcessInfo.processInfo.arguments.contains("--disable-transcripts") else { return }

        let effectiveIgnoreCache: Bool
        if ProcessInfo.processInfo.arguments.contains("--force-transcript-update") {
            effectiveIgnoreCache = true
        } else {
            effectiveIgnoreCache = ignoreCache
        }

        if !migratedTranscriptsToNativeVersion {
            log.debug("Transcripts need migration")
        }

        if !effectiveIgnoreCache && migratedTranscriptsToNativeVersion {
            guard TranscriptIndexer.needsUpdate(in: storage) else {
                log.debug("Skipping transcript indexing: TranscriptIndexer indicates no update is needed")
                return
            }
        }

        guard !didRunService else { return }
        didRunService = true

        appleClient.fetchConfig { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let config):
                self.doStartTranscriptIndexing(with: config, ignoringCache: effectiveIgnoreCache)
            case .failure(let error):
                log.error("Config fetch failed: \(String(describing: error), privacy: .public)")
            }
        }
    }

    private func doStartTranscriptIndexing(with config: ConfigResponse, ignoringCache ignoreCache: Bool) {
        log.debug("\(#function, privacy: .public)")

        guard let feeds = config.feeds[transcriptLanguage] ?? config.feeds[ConfigResponse.fallbackFeedLanguage] else {
            log.error("No feeds found for currently set language (\(self.transcriptLanguage)) or fallback language (\(ConfigResponse.fallbackFeedLanguage))")
            return
        }
        
        guard let transcriptsFeedURL = feeds.transcripts?.url else {
            log.error("Manifest doesn't have a URL for the transcripts feed")
            return
        }

        guard let storageURL = storage.realmConfig.fileURL else { return }

        TranscriptIndexer.lastManifestBasedUpdateDate = Date()
        migratedTranscriptsToNativeVersion = true

        transcriptIndexingService?.indexTranscriptsIfNeeded(
            manifestURL: transcriptsFeedURL,
            ignoringCache: ignoreCache,
            storageURL: storageURL,
            schemaVersion: storage.realmConfig.schemaVersion
        )
    }

    func transcriptIndexingStarted() {
        log.debug("\(#function, privacy: .public)")

        isIndexing = true
    }

    func transcriptIndexingProgressDidChange(_ progress: Float) {
        indexingProgress = progress
    }

    func transcriptIndexingStopped() {
        log.debug("\(#function, privacy: .public)")

        isIndexing = false
    }

}
