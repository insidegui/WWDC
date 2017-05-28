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
    public static let TranscriptIndexingDidStart = Notification.Name("TranscriptIndexingDidStartNotification")
    public static let TranscriptIndexingDidStop = Notification.Name("TranscriptIndexingDidStopNotification")
}

public final class TranscriptIndexer {
    
    private let storage: Storage
    
    public init(_ storage: Storage) {
        self.storage = storage
    }
    
    /// Whether transcripts are currently being indexed
    public var isIndexingTranscripts = false {
        didSet {
            guard oldValue != isIndexingTranscripts else { return }
            
            let notificationName: Notification.Name = isIndexingTranscripts ? .TranscriptIndexingDidStart : .TranscriptIndexingDidStop
            
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: notificationName, object: nil)
            }
        }
    }
    
    /// The progress when the transcripts are being downloaded/indexed
    public var transcriptIndexingProgress: Progress? {
        didSet {
            isIndexingTranscripts = (transcriptIndexingProgress != nil)
            
            transcriptIndexingStartedCallback?()
        }
    }
    
    /// Called when transcript downloading/indexing starts,
    /// use `transcriptIndexingProgress` to track progress
    public var transcriptIndexingStartedCallback: (() -> Void)?
    
    private let asciiWWDCURL = "http://asciiwwdc.com/"
    
    fileprivate let bgThread = DispatchQueue.global(qos: .background)
    
    fileprivate lazy var backgroundOperationQueue: OperationQueue = {
        let q = OperationQueue()
        
        q.underlyingQueue = self.bgThread
        q.name = "Transcript Indexing"
        
        return q
    }()
    
    /// Try to download transcripts for sessions that don't have transcripts yet
    func downloadTranscriptsIfNeeded() {
        
        let transcriptedSessions = storage.realm.objects(Session.self).filter("transcript == nil AND SUBQUERY(assets, $asset, $asset.rawAssetType == %@).@count > 0", SessionAssetType.streamingVideo.rawValue)
        
        let sessionKeys: [String] = transcriptedSessions.map({ $0.identifier })
        
        self.indexTranscriptsForSessionsWithKeys(sessionKeys)
    }
    
    func indexTranscriptsForSessionsWithKeys(_ sessionKeys: [String]) {
        guard !isIndexingTranscripts else { return }
        guard sessionKeys.count > 0 else { return }
        
        transcriptIndexingProgress = Progress(totalUnitCount: Int64(sessionKeys.count))
        
        for key in sessionKeys {
            guard let session = storage.realm.object(ofType: Session.self, forPrimaryKey: key) else { return }
            
            guard session.transcript == nil else { continue }
            
            indexTranscript(for: session.number, in: session.year, primaryKey: key)
        }
    }
    
    fileprivate func indexTranscript(for sessionNumber: String, in year: Int, primaryKey: String) {
        guard let url = URL(string: "\(asciiWWDCURL)\(year)//sessions/\(sessionNumber)") else { return }
        
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let task = URLSession.shared.dataTask(with: request) { [unowned self] data, response, error in
            guard let jsonData = data else {
                print("No data returned from ASCIIWWDC for \(primaryKey)")
                return
            }
            
            self.backgroundOperationQueue.addOperation {
                do {
                    let bgRealm = try Realm(configuration: self.storage.realmConfig)
                    
                    guard let session = bgRealm.object(ofType: Session.self, forPrimaryKey: primaryKey) else { return }
                    
                    let result = TranscriptsJSONAdapter().adapt(JSON(data: jsonData))
                    
                    guard case .success(let transcript) = result else {
                        NSLog("Error parsing transcript for \(primaryKey)")
                        return
                    }
                    
                    bgRealm.beginWrite()
                    bgRealm.add(transcript)
                    session.transcript = transcript
                    
                    try bgRealm.commitWrite()
                    
                    self.transcriptIndexingProgress?.completedUnitCount += 1
                } catch let error {
                    NSLog("Error indexing transcript for \(primaryKey): \(error)")
                }
                
                if let progress = self.transcriptIndexingProgress {
                    #if DEBUG
                        NSLog("Completed: \(progress.completedUnitCount) Total: \(progress.totalUnitCount)")
                    #endif
                    
                    if progress.completedUnitCount >= progress.totalUnitCount - 1 {
                        DispatchQueue.main.async {
                            #if DEBUG
                                NSLog("Transcript indexing finished")
                            #endif
                            self.isIndexingTranscripts = false
                        }
                    }
                }
            }
        }
        
        task.resume()
    }
    
}
