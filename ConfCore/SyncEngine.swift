//
//  SyncEngine.swift
//  WWDC
//
//  Created by Guilherme Rambo on 22/04/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Foundation
import RxCocoa
import RxSwift
import os.log

extension Notification.Name {
    public static let SyncEngineDidSyncSessionsAndSchedule = Notification.Name("SyncEngineDidSyncSessionsAndSchedule")
    public static let SyncEngineDidSyncFeaturedSections = Notification.Name("SyncEngineDidSyncFeaturedSections")
}

public final class SyncEngine {

    private let log = OSLog(subsystem: "ConfCore", category: String(describing: SyncEngine.self))

    public let storage: Storage
    public let client: AppleAPIClient

    #if ICLOUD
    public let userDataSyncEngine: UserDataSyncEngine
    #endif

    private let disposeBag = DisposeBag()

    public init(storage: Storage, client: AppleAPIClient, transcriptLanguage: String) {
        self.storage = storage
        self.client = client
        self.transcriptLanguage = transcriptLanguage

        #if ICLOUD
        self.userDataSyncEngine = UserDataSyncEngine(storage: storage)
        #endif

        NotificationCenter.default.rx.notification(.SyncEngineDidSyncSessionsAndSchedule).observeOn(MainScheduler.instance).subscribe(onNext: { [unowned self] _ in
            self.startTranscriptIndexing(ignoringCache: !self.migratedTranscriptsToNativeVersion)

            #if ICLOUD
            self.userDataSyncEngine.start()
            #endif
        }).disposed(by: disposeBag)
    }

    public func syncContent() {
        client.fetchContent { [unowned self] scheduleResult in
            DispatchQueue.main.async {
                self.storage.store(contentResult: scheduleResult) { error in
                    NotificationCenter.default.post(name: .SyncEngineDidSyncSessionsAndSchedule, object: error)

                    guard error == nil else { return }

                    self.syncFeaturedSections()
                }
            }
        }
    }

    public func syncLiveVideos(completion: (() -> Void)? = nil) {
        client.fetchLiveVideoAssets { [weak self] result in
            DispatchQueue.main.async {
                self?.storage.store(liveVideosResult: result)
                completion?()
            }
        }
    }

    public func syncFeaturedSections() {
        client.fetchFeaturedSections { [weak self] result in
            DispatchQueue.main.async {
                self?.storage.store(featuredSectionsResult: result) { error in
                    NotificationCenter.default.post(name: .SyncEngineDidSyncFeaturedSections, object: error)
                }
            }
        }
    }

    // MARK: - Transcripts

    public var transcriptLanguage: String {
        didSet {
            guard transcriptLanguage != oldValue else { return }

            didRunIndexingService = false
            startTranscriptIndexing(ignoringCache: true)
        }
    }

    private var didRunIndexingService = false

    private lazy var transcriptIndexingConnection: NSXPCConnection = {
        let c = NSXPCConnection(serviceName: "io.wwdc.app.TranscriptIndexingService")

        c.remoteObjectInterface = NSXPCInterface(with: TranscriptIndexingServiceProtocol.self)

        return c
    }()

    private var transcriptIndexingService: TranscriptIndexingServiceProtocol? {
        return transcriptIndexingConnection.remoteObjectProxy as? TranscriptIndexingServiceProtocol
    }

    private var migratedTranscriptsToNativeVersion: Bool {
        get { UserDefaults.standard.bool(forKey: #function) }
        set { UserDefaults.standard.set(newValue, forKey: #function) }
    }

    private func startTranscriptIndexing(ignoringCache ignoreCache: Bool) {
        guard !ProcessInfo.processInfo.arguments.contains("--disable-transcripts") else { return }

        if !migratedTranscriptsToNativeVersion {
            os_log("Transcripts need migration", log: self.log, type: .debug)
        }

        if !ignoreCache {
            guard TranscriptIndexer.needsUpdate(in: storage) else { return }
        }

        guard !didRunIndexingService else { return }
        didRunIndexingService = true

        client.fetchConfig { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let config):
                self.doStartTranscriptIndexing(with: config, ignoringCache: ignoreCache)
            case .failure(let error):
                os_log("Config fetch failed: %{public}@", log: self.log, type: .error, String(describing: error))
            }
        }

    }

    private func doStartTranscriptIndexing(with config: RootConfig, ignoringCache ignoreCache: Bool) {
        os_log("%{public}@", log: log, type: .debug, #function)

        guard let feeds = config.feeds[transcriptLanguage] ?? config.feeds[RootConfig.fallbackFeedLanguage] else {
            os_log("No feeds found for currently set language (%@) or fallback language (%@)", log: self.log, type: .error, transcriptLanguage, RootConfig.fallbackFeedLanguage)
            return
        }

        guard let storageURL = storage.realmConfig.fileURL else { return }

        TranscriptIndexer.lastManifestBasedUpdateDate = Date()
        migratedTranscriptsToNativeVersion = true

        transcriptIndexingConnection.resume()

        transcriptIndexingService?.indexTranscriptsIfNeeded(
            manifestURL: feeds.transcripts.url,
            ignoringCache: ignoreCache,
            storageURL: storageURL,
            schemaVersion: storage.realmConfig.schemaVersion
        )
    }

}
