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

extension Notification.Name {
    public static let SyncEngineDidSyncSessionsAndSchedule = Notification.Name("SyncEngineDidSyncSessionsAndSchedule")
}

public final class SyncEngine {

    public let storage: Storage
    public let client: AppleAPIClient

    #if ICLOUD
    public let userDataSyncEngine: UserDataSyncEngine
    #endif

    private var didRunIndexingService = false

    private lazy var transcriptIndexingConnection: NSXPCConnection = {
        let c = NSXPCConnection(serviceName: "io.wwdc.app.TranscriptIndexingService")

        c.remoteObjectInterface = NSXPCInterface(with: TranscriptIndexingServiceProtocol.self)

        return c
    }()

    private var transcriptIndexingService: TranscriptIndexingServiceProtocol? {
        return transcriptIndexingConnection.remoteObjectProxy as? TranscriptIndexingServiceProtocol
    }

    private let disposeBag = DisposeBag()

    public init(storage: Storage, client: AppleAPIClient) {
        self.storage = storage
        self.client = client

        #if ICLOUD
        self.userDataSyncEngine = UserDataSyncEngine(storage: storage)
        #endif

        NotificationCenter.default.rx.notification(.SyncEngineDidSyncSessionsAndSchedule).observeOn(MainScheduler.instance).subscribe(onNext: { [unowned self] _ in
            self.startTranscriptIndexingIfNeeded()
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

//                    guard error == nil else { return }

//                    self.syncFeaturedSections()
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
                self?.storage.store(featuredSectionsResult: result)
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
