//
//  SyncEngine.swift
//  WWDC
//
//  Created by Guilherme Rambo on 22/04/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Foundation
import OSLog
import Combine

extension Notification.Name {
    public static let SyncEngineDidSyncSessionsAndSchedule = Notification.Name("SyncEngineDidSyncSessionsAndSchedule")
    public static let SyncEngineDidSyncFeaturedSections = Notification.Name("SyncEngineDidSyncFeaturedSections")
}

@MainActor
public final class SyncEngine: Logging {

    public static let log = makeLogger()

    public let storage: Storage
    public let client: AppleAPIClient

    public let userDataSyncEngine: UserDataSyncEngine?

    private var cancellables: Set<AnyCancellable> = []

    let transcriptIndexingClient: TranscriptIndexingClient

    public var transcriptLanguage: String {
        get { transcriptIndexingClient.transcriptLanguage }
        set { transcriptIndexingClient.transcriptLanguage = newValue }
    }

    public var isIndexingTranscripts: AnyPublisher<Bool, Never> { transcriptIndexingClient.$isIndexing.eraseToAnyPublisher() }
    public var transcriptIndexingProgress: AnyPublisher<Float, Never> { transcriptIndexingClient.$indexingProgress.eraseToAnyPublisher() }

    public init(storage: Storage, client: AppleAPIClient, transcriptLanguage: String) {
        self.storage = storage
        self.client = client

        self.transcriptIndexingClient = TranscriptIndexingClient(
            language: transcriptLanguage,
            storage: storage
        )

        if ConfCoreCapabilities.isCloudKitEnabled {
            self.userDataSyncEngine = UserDataSyncEngine(storage: storage)
        } else {
            self.userDataSyncEngine = nil
        }

        NotificationCenter.default.publisher(for: .SyncEngineDidSyncSessionsAndSchedule).receive(on: DispatchQueue.main).sink(receiveValue: { [unowned self] _ in
            self.transcriptIndexingClient.startIndexing(ignoringCache: false)

            self.userDataSyncEngine?.start()
        }).store(in: &cancellables)
    }

    public func syncContent() {
        client.fetchContent { [unowned self] scheduleResult in
            DispatchQueue.main.async {
                self.storage.store(contentResult: scheduleResult) { error in
                    NotificationCenter.default.post(name: .SyncEngineDidSyncSessionsAndSchedule, object: error)

                    guard error == nil else { return }

                    self.userDataSyncEngine?.commitRecordsPendingContentSyncIfNeeded()
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

    public func syncConfiguration() {
        client.fetchConfig { [weak self] result in
            DispatchQueue.main.async {
                self?.storage.store(configResult: result, completion: { _ in })
            }
        }
    }

}
