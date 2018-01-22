//
//  TranscriptIndexer.swift
//  WWDC
//
//  Created by Guilherme Rambo on 27/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
import RealmSwift
import SwiftyJSON

extension Notification.Name {
    public static let TranscriptIndexingDidStart = Notification.Name("io.wwdc.app.TranscriptIndexingDidStartNotification")
    public static let TranscriptIndexingDidStop = Notification.Name("io.wwdc.app.TranscriptIndexingDidStopNotification")
}

public final class TranscriptIndexer: NSObject {

    private let storage: Storage

    public init(_ storage: Storage) {
        self.storage = storage

        super.init()
    }

    /// The progress when the transcripts are being downloaded/indexed
    public var transcriptIndexingProgress: Progress?

    private let asciiWWDCURL = "http://asciiwwdc.com/"

    fileprivate let bgThread = DispatchQueue.global(qos: .utility)

    fileprivate lazy var backgroundOperationQueue: OperationQueue = {
        let q = OperationQueue()

        q.underlyingQueue = self.bgThread
        q.name = "Transcript Indexing"

        return q
    }()

    public static let minTranscriptableSessionLimit: Int = 20
    // TODO: increase 2017 to 2018 when transcripts for 2017 become available
    public static let transcriptableSessionsPredicate: NSPredicate = NSPredicate(format: "year > 2012 AND year < 2017 AND transcriptIdentifier == '' AND SUBQUERY(assets, $asset, $asset.rawAssetType == %@).@count > 0", SessionAssetType.streamingVideo.rawValue)

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

            guard session.transcriptIdentifier.isEmpty else { continue }

            indexTranscript(for: session.number, in: session.year, primaryKey: key)
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
        storage.backgroundUpdate { backgroundRealm in
            transcripts.forEach { transcript in
                guard let session = backgroundRealm.object(ofType: Session.self, forPrimaryKey: transcript.identifier) else {
                    NSLog("Session not found for \(transcript.identifier)")
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

        let task = URLSession.shared.dataTask(with: request) { [unowned self] data, response, error in
            defer {
                self.transcriptIndexingProgress?.completedUnitCount += 1

                self.checkForCompletion()
            }

            guard let jsonData = data else {
                NSLog("No data returned from ASCIIWWDC for \(primaryKey)")

                return
            }

            let result = TranscriptsJSONAdapter().adapt(JSON(data: jsonData))

            guard case .success(let transcript) = result else {
                NSLog("Error parsing transcript for \(primaryKey)")
                return
            }

            self.storage.storageQueue.waitUntilAllOperationsAreFinished()

            self.batch.append(transcript)
        }

        task.resume()
    }

    public override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == #keyPath(OperationQueue.operationCount) {
            NSLog("operationCount = \(backgroundOperationQueue.operationCount)")
        } else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }

    private func checkForCompletion() {
        guard let progress = transcriptIndexingProgress else { return }

        #if DEBUG
            NSLog("Completed: \(progress.completedUnitCount) Total: \(progress.totalUnitCount)")
        #endif

        if progress.completedUnitCount >= progress.totalUnitCount {
            DispatchQueue.main.async {
                #if DEBUG
                    NSLog("Transcript indexing finished")
                #endif

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
