//
//  TranscriptIndexingService.swift
//  WWDC
//
//  Created by Guilherme Rambo on 28/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Foundation
import RealmSwift
import OSLog

@objcMembers public final class TranscriptIndexingService: NSObject, TranscriptIndexingServiceProtocol, Logging {

    private var indexer: TranscriptIndexer!
    public static let log = makeLogger()

    public func indexTranscriptsIfNeeded(manifestURL: URL, ignoringCache: Bool, storageURL: URL, schemaVersion: UInt64) {
        log.debug("Attempting to index transcripts. manifest: \(manifestURL, privacy: .public), ignoringCache: \(ignoringCache)")
        do {
            let config = Realm.Configuration(fileURL: storageURL, schemaVersion: schemaVersion)
            let realm = try Realm(configuration: config)
            let storage = Storage(realm)

            indexer = TranscriptIndexer(storage, manifestURL: manifestURL)

            indexer.didStart = { [weak self] in
                self?.clients.forEach { $0.transcriptIndexingStarted() }
            }
            indexer.progressChanged = { [weak self] progress in
                self?.clients.forEach { $0.transcriptIndexingProgressDidChange(progress) }
            }
            indexer.didStop = { [weak self] in
                self?.clients.forEach { $0.transcriptIndexingStopped() }
            }

            indexer.manifestURL = manifestURL
            indexer.ignoreExistingEtags = ignoringCache

            indexer.downloadTranscriptsIfNeeded()
        } catch {
            log.fault("Error initializing indexing service: \(String(describing: error), privacy: .public)")
            return
        }
    }

    private lazy var listener: NSXPCListener = {
        let l = NSXPCListener.service()

        l.delegate = self

        return l
    }()

    public func resume() {
        listener.resume()
    }

    private var connections: [NSXPCConnection] = []

    private var clients: [TranscriptIndexingClientProtocol] {
        connections.compactMap { $0.remoteObjectProxy as? TranscriptIndexingClientProtocol }
    }

}

extension TranscriptIndexingService: NSXPCListenerDelegate {

    public func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        newConnection.exportedInterface = NSXPCInterface(with: TranscriptIndexingServiceProtocol.self)
        newConnection.exportedObject = self

        newConnection.remoteObjectInterface = NSXPCInterface(with: TranscriptIndexingClientProtocol.self)

        newConnection.invalidationHandler = { [weak self] in
            guard let self = self else { return }

            log.debug("Connection invalidated: \(String(describing: newConnection), privacy: .public)")

            self.connections.removeAll(where: { $0 == newConnection })
        }

        connections.append(newConnection)

        newConnection.resume()

        return true
    }

}
