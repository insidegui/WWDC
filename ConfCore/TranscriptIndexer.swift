//
//  TranscriptIndexer.swift
//  WWDC
//
//  Created by Guilherme Rambo on 27/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
import RealmSwift
import Transcripts
import os.log

extension Notification.Name {
    public static let TranscriptIndexingDidStart = Notification.Name("io.wwdc.app.TranscriptIndexingDidStartNotification")
    public static let TranscriptIndexingDidStop = Notification.Name("io.wwdc.app.TranscriptIndexingDidStopNotification")
}

public final class TranscriptIndexer {

    private let storage: Storage
    private static let log = OSLog(subsystem: "ConfCore", category: "TranscriptIndexer")
    private let log = TranscriptIndexer.log
    public var manifestURL: URL
    public var ignoreExistingEtags = false

    public init(_ storage: Storage, manifestURL: URL) {
        self.storage = storage
        self.manifestURL = manifestURL
    }

    fileprivate let queue = DispatchQueue(label: "Transcript Indexer", qos: .background)

    fileprivate lazy var backgroundOperationQueue: OperationQueue = {
        let q = OperationQueue()

        q.underlyingQueue = self.queue
        q.name = "Transcript Indexing"

        return q
    }()

    private lazy var onQueueRealm: Realm = {
        // swiftlint:disable:next force_try
        try! storage.makeRealm()
    }()

    /// How many days before transcripts will be refreshed based on the remote manifest, ignoring
    /// sessions which already have local transcripts.
    private static let minimumIntervalInDaysBetweenManifestBasedUpdates = 5

    /// The last time a transcript fetch was performed based on the remote manifest.
    public static var lastManifestBasedUpdateDate: Date {
        get { UserDefaults.standard.object(forKey: #function) as? Date ?? .distantPast }
        set { UserDefaults.standard.set(newValue, forKey: #function) }
    }

    private static var shouldFetchRemoteManifest: Bool {
        guard let days = Calendar.current.dateComponents(Set([.day]), from: lastManifestBasedUpdateDate, to: Date()).day else { return false }
        return days > minimumIntervalInDaysBetweenManifestBasedUpdates
    }

    public static let minTranscriptableSessionLimit: Int = 30

    public static let transcriptableSessionsPredicate: NSPredicate = NSPredicate(format: "ANY event.year > 2012 AND ANY event.year <= 2020 AND transcriptIdentifier == '' AND SUBQUERY(assets, $asset, $asset.rawAssetType == %@).@count > 0", SessionAssetType.streamingVideo.rawValue)

    public static func needsUpdate(in storage: Storage) -> Bool {
        // Manifest-based updates.
        guard !shouldFetchRemoteManifest else {
            os_log("Transcripts will be checked against remote manifest", log: self.log, type: .debug)
            return true
        }

        // Local cache-based updates.
        let transcriptedSessions = storage.realm.objects(Session.self).filter(TranscriptIndexer.transcriptableSessionsPredicate)

        return transcriptedSessions.count > minTranscriptableSessionLimit
    }

    private func makeDownloader() -> TranscriptDownloader {
        TranscriptDownloader(manifestURL: manifestURL, storage: self)
    }

    private lazy var downloader: TranscriptDownloader = {
        makeDownloader()
    }()

    var didStart: () -> Void = { }
    var progressChanged: (Float) -> Void = { _ in }
    var didStop: () -> Void = { }

    public func downloadTranscriptsIfNeeded() {
        downloader = makeDownloader()

        didStart()

        DistributedNotificationCenter.default().postNotificationName(
            .TranscriptIndexingDidStart,
            object: nil,
            userInfo: nil,
            options: .deliverImmediately
        )

        do {
            let realm = try storage.makeRealm()

            let knownSessionIds = Array(realm.objects(Session.self).map(\.identifier))

            os_log("Got %d session IDs", log: self.log, type: .debug, knownSessionIds.count)

            downloader.fetch(validSessionIdentifiers: knownSessionIds, progress: { [weak self] progress in
                guard let self = self else { return }

                os_log("Transcript indexing progresss: %.2f", log: self.log, type: .default, progress)

                self.progressChanged(progress)
            }) { [weak self] in
                self?.finished()
            }
        } catch {
            os_log("Failed to initialize Realm: %{public}@", log: self.log, type: .fault, String(describing: error))
        }
    }

    fileprivate func store(_ transcripts: [Transcript]) {
        storage.backgroundUpdate { [weak self] backgroundRealm in
            guard let self = self else { return }
            os_log("Start transcript realm updates", log: self.log, type: .debug)

            transcripts.forEach { transcript in
                guard let session = backgroundRealm.object(ofType: Session.self, forPrimaryKey: transcript.identifier) else {
                    os_log("Corresponding session not found for transcript with identifier %{public}@",
                           log: self.log,
                           type: .error,
                           transcript.identifier)

                    return
                }

                session.transcriptIdentifier = transcript.identifier
                session.transcriptText = transcript.fullText

                backgroundRealm.add(transcript, update: .modified)
            }

            os_log("Finished transcript realm updates", log: self.log, type: .debug)
        }
    }

    private func finished() {
        didStop()

        DistributedNotificationCenter.default().postNotificationName(
            .TranscriptIndexingDidStop,
            object: nil,
            userInfo: nil,
            options: .deliverImmediately
        )
    }

}

extension TranscriptIndexer: TranscriptStorage {

    public func previousEtag(for identifier: String) -> String? {
        guard !ignoreExistingEtags else { return nil }

        return onQueueRealm.object(ofType: Transcript.self, forPrimaryKey: identifier)?.etag
    }

    public func store(_ transcripts: [TranscriptContent], manifest: TranscriptManifest) {
        let transcriptObjects: [Transcript] = transcripts.map { model in
            let obj = Transcript()

            obj.identifier = model.identifier
            obj.fullText = model.lines.map(\.text).joined()
            obj.etag = manifest.individual[model.identifier]?.etag

            let annotations: [TranscriptAnnotation] = model.lines.map { model in
                let obj = TranscriptAnnotation()

                obj.timecode = Double(model.time)
                obj.body = model.text.replacingOccurrences(of: "\n", with: "")

                return obj
            }

            obj.annotations.append(objectsIn: annotations)

            return obj
        }

        store(transcriptObjects)
    }

}
