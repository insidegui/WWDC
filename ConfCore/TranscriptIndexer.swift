//
//  TranscriptIndexer.swift
//  WWDC
//
//  Created by Guilherme Rambo on 27/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
import RealmSwift
import os.log

extension Notification.Name {
    public static let TranscriptIndexingDidStart = Notification.Name("io.wwdc.app.TranscriptIndexingDidStartNotification")
    public static let TranscriptIndexingDidStop = Notification.Name("io.wwdc.app.TranscriptIndexingDidStopNotification")
}

public final class TranscriptIndexer {

    private let storage: Storage
    private let log = OSLog(subsystem: "ConfCore", category: "TranscriptIndexer")

    public init(_ storage: Storage) {
        self.storage = storage
    }

    /// The progress when the transcripts are being downloaded/indexed
    public var transcriptIndexingProgress: Progress?

    private let asciiWWDCURL = "https://asciiwwdc.com/"

    fileprivate let bgThread = DispatchQueue.global(qos: .utility)

    fileprivate lazy var backgroundOperationQueue: OperationQueue = {
        let q = OperationQueue()

        q.underlyingQueue = self.bgThread
        q.name = "Transcript Indexing"

        return q
    }()

    public static let minTranscriptableSessionLimit: Int = 20

    // We specify the latest year known to have transcripts in the predicate to avoid firing lots of requests to ASCIIWWDC which would result in a 404
    public static let transcriptableSessionsPredicate: NSPredicate = NSPredicate(format: "ANY event.year > 2012 AND ANY event.year <= 2018 AND transcriptIdentifier == '' AND SUBQUERY(assets, $asset, $asset.rawAssetType == %@).@count > 0", SessionAssetType.streamingVideo.rawValue)

    public static func needsUpdate(in storage: Storage) -> Bool {
        let transcriptedSessions = storage.realm.objects(Session.self).filter(TranscriptIndexer.transcriptableSessionsPredicate)

        return transcriptedSessions.count > minTranscriptableSessionLimit
    }

    /// Try to download transcripts for sessions that don't have transcripts yet
    public func downloadTranscriptsIfNeeded() {
        let transcriptedSessions = storage.realm.objects(Session.self).filter(TranscriptIndexer.transcriptableSessionsPredicate)

        let sessionKeys: [String] = transcriptedSessions.map({ $0.identifier })

        indexTranscriptsForSessionsWithKeys(sessionKeys)
    }

    func indexTranscriptsForSessionsWithKeys(_ sessionKeys: [String]) {
        // ignore very low session counts
        guard sessionKeys.count > TranscriptIndexer.minTranscriptableSessionLimit else {
            waitAndExit()
            return
        }

        transcriptIndexingProgress = Progress(totalUnitCount: Int64(sessionKeys.count))

        for key in sessionKeys {
            guard let session = storage.realm.object(ofType: Session.self, forPrimaryKey: key) else { return }
            guard let event = session.event.first else { return }

            guard session.transcriptIdentifier.isEmpty else { continue }

            indexTranscript(for: session.number, in: event.year, primaryKey: key)
        }
    }

    fileprivate var batch: [Transcript] = [] {
        didSet {
            if batch.count >= 20 {
                store(batch)
                storage.storageQueue.waitUntilAllOperationsAreFinished()
                batch.removeAll()
            }
        }
    }

    fileprivate func store(_ transcripts: [Transcript]) {
        storage.backgroundUpdate { [weak self] backgroundRealm in
            guard let self = self else { return }

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

                backgroundRealm.add(transcript, update: true)
            }
        }
    }

    fileprivate func indexTranscript(for sessionNumber: String, in year: Int, primaryKey: String) {
        guard let url = URL(string: "\(asciiWWDCURL)\(year)//sessions/\(sessionNumber)") else { return }

        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }

            defer {
                self.transcriptIndexingProgress?.completedUnitCount += 1

                self.checkForCompletion()
            }

            guard let jsonData = data else {
                os_log("No data returned from ASCIIWWDC for transcript with identifier %{public}@",
                       log: self.log,
                       type: .error,
                       primaryKey)

                return
            }

            guard let transcript = try? JSONDecoder().decode(Transcript.self, from: jsonData) else {
                os_log("Error unserializing transcript with identifier %{public}@",
                       log: self.log,
                       type: .error,
                       primaryKey)
                return
            }

            self.storage.storageQueue.waitUntilAllOperationsAreFinished()

            self.batch.append(transcript)
        }

        task.resume()
    }

    private func checkForCompletion() {
        guard let progress = transcriptIndexingProgress else { return }

        os_log("Indexed %{public}d/%{public}d", log: log, type: .debug, progress.completedUnitCount, progress.totalUnitCount)

        if progress.completedUnitCount >= progress.totalUnitCount {
            DispatchQueue.main.async {
                os_log("Transcript indexing finished 🎉", log: self.log, type: .info)

                self.storage.storageQueue.waitUntilAllOperationsAreFinished()
                self.waitAndExit()
            }
        }
    }

    fileprivate func waitAndExit() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            exit(0)
        }
    }

}
