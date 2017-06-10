//
//  SyncEngine.swift
//  WWDC
//
//  Created by Guilherme Rambo on 22/04/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Foundation
import RxSwift

extension Notification.Name {
    public static let SyncEngineDidSyncSessionsAndSchedule = Notification.Name("SyncEngineDidSyncSessionsAndSchedule")
}

public final class SyncEngine {

    public let storage: Storage
    public let client: AppleAPIClient

    private var didRunIndexingService = false

    private lazy var transcriptIndexingConnection: NSXPCConnection = {
        let c = NSXPCConnection(serviceName: "io.wwdc.app.TranscriptIndexingService")

        c.remoteObjectInterface = NSXPCInterface(with: TranscriptIndexingServiceProtocol.self)

        return c
    }()

    private var transcriptIndexingService: TranscriptIndexingServiceProtocol? {
        return transcriptIndexingConnection.remoteObjectProxy as? TranscriptIndexingServiceProtocol
    }

    public init(storage: Storage, client: AppleAPIClient) {
        self.storage = storage
        self.client = client

        NotificationCenter.default.addObserver(forName: .SyncEngineDidSyncSessionsAndSchedule, object: nil, queue: OperationQueue.main) { [unowned self] _ in
            self.startTranscriptIndexingIfNeeded()
        }
    }

    public func syncContent() {
        client.fetchContent { [unowned self] scheduleResult in
            DispatchQueue.main.async {
                self.storage.store(contentResult: scheduleResult) {
                    NotificationCenter.default.post(name: .SyncEngineDidSyncSessionsAndSchedule, object: self)
                }
            }
        }
    }

    public func syncLiveVideos() {
        client.fetchLiveVideoAssets { [weak self] result in
            DispatchQueue.main.async {
                self?.storage.store(liveVideosResult: result)
            }
        }
    }

    private func startTranscriptIndexingIfNeeded() {
        guard !ProcessInfo.processInfo.arguments.contains("--disable-transcripts") else { return }

        guard TranscriptIndexer.needsUpdate(in: storage) else { return }

        guard let url = storage.realmConfig.fileURL else { return }

        guard !didRunIndexingService else { return }
        didRunIndexingService = true

        transcriptIndexingConnection.resume()

        transcriptIndexingService?.indexTranscriptsIfNeeded(storageURL: url, schemaVersion: storage.realmConfig.schemaVersion)
    }

}
