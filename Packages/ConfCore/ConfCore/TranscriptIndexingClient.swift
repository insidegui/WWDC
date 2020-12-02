//
//  TranscriptIndexingClient.swift
//  ConfCore
//
//  Created by Guilherme Rambo on 27/05/20.
//  Copyright © 2020 Guilherme Rambo. All rights reserved.
//

import Foundation
import RxSwift
import RxCocoa
import os.log

final class TranscriptIndexingClient: NSObject, TranscriptIndexingClientProtocol {

    private let log = OSLog(subsystem: "ConfCore", category: String(describing: TranscriptIndexingClient.self))

    var transcriptLanguage: String {
        didSet {
            guard transcriptLanguage != oldValue else { return }

            didRunService = false
            startIndexing(ignoringCache: true)
        }
    }

    private let storage: Storage
    private let appleClient: AppleAPIClient

    init(language: String, storage: Storage, appleClient: AppleAPIClient = AppleAPIClient(environment: .current)) {
        self.transcriptLanguage = language
        self.storage = storage
        self.appleClient = appleClient

        super.init()

        transcriptIndexingConnection.resume()
    }

    private(set) var isIndexing = BehaviorRelay<Bool>(value: false)
    private(set) var indexingProgress = BehaviorRelay<Float>(value: 0)

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
            os_log("Failed to get remote object proxy: %{public}@", log: self.log, type: .fault, String(describing: error))
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
            os_log("Transcripts need migration", log: self.log, type: .debug)
        }

        if !effectiveIgnoreCache && migratedTranscriptsToNativeVersion {
            guard TranscriptIndexer.needsUpdate(in: storage) else { return }
        }

        guard !didRunService else { return }
        didRunService = true

        appleClient.fetchConfig { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let config):
                self.doStartTranscriptIndexing(with: config, ignoringCache: effectiveIgnoreCache)
            case .failure(let error):
                os_log("Config fetch failed: %{public}@", log: self.log, type: .error, String(describing: error))
            }
        }
    }

    private func doStartTranscriptIndexing(with config: ConfigResponse, ignoringCache ignoreCache: Bool) {
        os_log("%{public}@", log: log, type: .debug, #function)

        guard let feeds = config.feeds[transcriptLanguage] ?? config.feeds[ConfigResponse.fallbackFeedLanguage] else {
            os_log("No feeds found for currently set language (%@) or fallback language (%@)", log: self.log, type: .error, transcriptLanguage, ConfigResponse.fallbackFeedLanguage)
            return
        }

        guard let storageURL = storage.realmConfig.fileURL else { return }

        TranscriptIndexer.lastManifestBasedUpdateDate = Date()
        migratedTranscriptsToNativeVersion = true

        transcriptIndexingService?.indexTranscriptsIfNeeded(
            manifestURL: feeds.transcripts.url,
            ignoringCache: ignoreCache,
            storageURL: storageURL,
            schemaVersion: storage.realmConfig.schemaVersion
        )
    }

    func transcriptIndexingStarted() {
        os_log("%{public}@", log: log, type: .debug, #function)

        isIndexing.accept(true)
    }

    func transcriptIndexingProgressDidChange(_ progress: Float) {
        indexingProgress.accept(progress)
    }

    func transcriptIndexingStopped() {
        os_log("%{public}@", log: log, type: .debug, #function)

        isIndexing.accept(false)
    }

}
