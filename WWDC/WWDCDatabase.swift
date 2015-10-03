//
//  SessionFetcher.swift
//  WWDC Data Layer Rewrite
//
//  Created by Guilherme Rambo on 01/10/15.
//  Copyright © 2015 Guilherme Rambo. All rights reserved.
//

import Foundation
import RealmSwift
import Alamofire

func mainQS(block: () -> ()) {
    dispatch_sync(dispatch_get_main_queue(), block)
}
func mainQ(block: () -> ()) {
    dispatch_async(dispatch_get_main_queue(), block)
}

private let _sharedWWDCDatabase = WWDCDatabase()

typealias SessionsUpdatedCallback = () -> Void

@objc class WWDCDatabase: NSObject {
    
    private struct Constants {
        static let internalServiceURL = "http://wwdc.guilhermerambo.me/index.json"
        static let liveServiceURL = "http://wwdc.guilhermerambo.me/live.json"
        static let liveNextServiceURL = "http://wwdc.guilhermerambo.me/next.json"
        static let asciiServiceBaseURL = "http://asciiwwdc.com/"
    }

    class var sharedDatabase: WWDCDatabase {
        return _sharedWWDCDatabase
    }
    
    private let bgThread = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0)
    private var transcriptIndexingQueue = NSOperationQueue()
    
    private var config: AppConfig! {
        didSet {
            guard config != nil else { return }
            
            updateSessionVideos()
        }
    }
    
    let realm = try! Realm()
    
    /// Use this to change properties of model objects **on the main thread**
    /// - Warning: if you try to change properties of model objects (such as Session) outside a `doChanges` block, an exception will be thrown
    func doChanges(block: () -> Void) {
        realm.beginWrite()
        block()
        realm.commitWrite()
    }
    
    /// Use this to change properties of model objects **on a background thread**
    /// - Note: This will not setup the thread for you, It is your responsibility to enter a background thread and then call `doBackgroundChanges`
    /// - Warning: if you try to change properties of model objects (such as Session) outside a `doChanges` block, an exception will be thrown
    /// - Warning: if you try to directly change a model fetched from another thread, an exception will be thrown.
    /// If you need to change a model fetched on another thread, re-fetch it using the provided realm before making the changes
    func doBackgroundChanges(block: (realm: Realm) -> Void) {
        let bgRealm = try! Realm()
        bgRealm.beginWrite()
        block(realm: bgRealm)
        bgRealm.commitWrite()
    }
    
    /// The progress when the transcripts are being downloaded/indexed
    var transcriptIndexingProgress: NSProgress? {
        didSet {
            transcriptIndexingStartedCallback?()
        }
    }
    /// Called when transcript downloading/indexing starts,
    /// use `transcriptIndexingProgress` to track progress
    var transcriptIndexingStartedCallback: (() -> Void)?
    
    /// A callback to execute whenever new sessions are available
    /// - parameter newSessionKeys: The keys (uniqueId) for the new sessions
    var sessionListChangedCallback: ((newSessionKeys: [String]) -> Void)?
    
    /// This is the main "sync" function
    /// #### The following steps are performed when `refresh()` is called:
    /// 1. Check to see if the URL for Apple's service has changed and update app config accordingly
    /// 2. Call Apple's service to get the list of session videos
    /// 3. Parse the results and update the local database
    /// 4. Fetch and index transcripts from ASCIIWWDC
    func refresh() {
        // try to find an existing AppConfig object in the database
        let fetchedConfig = realm.objects(AppConfig.self)
        if fetchedConfig.count > 0 {
            self.config = fetchedConfig[0]
        }
        
        fetchOrUpdateAppleServiceURLs()
    }
    
    /// Returns the list of sessions available
    /// - Warning: can only be used from the main thread
    var standardSessionList: Results<Session> {
        return realm.objects(Session.self).sorted(sortDescriptorsForSessionList)
    }
    
    /// #### The best sort descriptors for the list of videos
    /// Orders the videos by year (descending) and session number (ascending)
    lazy var sortDescriptorsForSessionList: [SortDescriptor] = [SortDescriptor(property: "year", ascending: false), SortDescriptor(property: "id", ascending: true)]
    
    private func fetchOrUpdateAppleServiceURLs() {
        Alamofire.request(.GET, Constants.internalServiceURL).response { _, _, data, error in
            guard let jsonData = data else {
                print("No data returned from internal server!")
                return
            }
            
            let fetchedConfig = AppConfig(json: JSON(data: jsonData))
            
            // if the fetched config from the service is equal to the config in the database, don't bother updating It
            guard !fetchedConfig.isEqualToConfig(self.config) else { return }
            
            print("AppConfig changed")
            
            // write the new configuration to the database so It can be fetched quickly later :)
            self.realm.write { self.realm.add(fetchedConfig, update: true) }
            self.config = fetchedConfig
        }
    }
    
    private func updateSessionVideos() {
        Alamofire.request(.GET, config.videosURL).response { _, _, data, error in
            dispatch_async(self.bgThread) {
                let backgroundRealm = try! Realm()
                
                guard let jsonData = data else {
                    print("No data returned from Apple's (session videos) server!")
                    return
                }
                
                let json = JSON(data: jsonData)
                
                var newVideosAvailable = true
                
                mainQS {
                    // check if the videos have been updated since the last fetch
                    if json["updated"].stringValue == self.config.videosUpdatedAt {
                        print("Video list did not change")
                        newVideosAvailable = false
                    } else {
                        self.realm.write { self.config.videosUpdatedAt = json["updated"].stringValue }
                    }
                }
                
                guard newVideosAvailable else { return }
                
                guard let sessionsArray = json["sessions"].array else {
                    print("Could not parse array of sessions")
                    return
                }
                
                var newSessionKeys: [String] = []
                
                // create and store/update each video
                for jsonSession in sessionsArray {
                    let session = Session(json: jsonSession)
                    if backgroundRealm.objectForPrimaryKey(Session.self, key: session.uniqueId) == nil {
                        newSessionKeys.append(session.uniqueId)
                    }
                    backgroundRealm.beginWrite()
                    backgroundRealm.add(session, update: true)
                    backgroundRealm.commitWrite()
                }
                
                self.indexTranscriptsForSessionsWithKeys(newSessionKeys)
                mainQ { self.sessionListChangedCallback?(newSessionKeys: newSessionKeys) }
            }
        }
    }
    
    private func indexTranscriptsForSessionsWithKeys(sessionKeys: [String]) {
        guard sessionKeys.count > 0 else { return }
        
        transcriptIndexingProgress = NSProgress(totalUnitCount: Int64(sessionKeys.count))
        transcriptIndexingQueue.underlyingQueue = bgThread
        transcriptIndexingQueue.name = "Transcript indexing"
        
        let backgroundRealm = try! Realm()
        
        for key in sessionKeys {
            guard let session = backgroundRealm.objectForPrimaryKey(Session.self, key: key) else { return }
            indexTranscriptForSession(session)
        }
    }
    
    private func indexTranscriptForSession(session: Session) {
        // TODO: check if transcript has been updated and index It again if It has (https://github.com/ASCIIwwdc/asciiwwdc.com/issues/24)
        guard session.transcript == nil else { return }
        
        let sessionKey = session.uniqueId
        let url = "\(Constants.asciiServiceBaseURL)\(session.year)//sessions/\(session.id)"
        let headers = ["Accept": "application/json"]
        Alamofire.request(.GET, url, parameters: nil, encoding: .JSON, headers: headers).response { _, response, data, error in
            guard let jsonData = data else {
                print("No data returned from ASCIIWWDC for session \(session.uniqueId)")
                return
            }
            
            self.transcriptIndexingQueue.addOperationWithBlock {
                let bgRealm = try! Realm()
                guard let session = bgRealm.objectForPrimaryKey(Session.self, key: sessionKey) else { return }
                let transcript = Transcript(json: JSON(data: jsonData), session: session)
                bgRealm.beginWrite()
                bgRealm.add(transcript)
                bgRealm.commitWrite()
                self.transcriptIndexingProgress?.completedUnitCount += 1
            }
        }
    }
    
}