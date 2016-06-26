//
//  SessionFetcher.swift
//  WWDC Data Layer Rewrite
//
//  Created by Guilherme Rambo on 01/10/15.
//  Copyright © 2015 Guilherme Rambo. All rights reserved.
//

// TODO: share model layer between OS X and tvOS, not just copy the files around

import Foundation
import RealmSwift
import Alamofire
import SwiftyJSON

func mainQS(block: () -> ()) {
    dispatch_sync(dispatch_get_main_queue(), block)
}
func mainQ(block: () -> ()) {
    dispatch_async(dispatch_get_main_queue(), block)
}

private let _sharedWWDCDatabase = WWDCDatabase()

typealias SessionsUpdatedCallback = () -> Void

let WWDCWeekDidStartNotification = "WWDCWeekDidStartNotification"
let WWDCWeekDidEndNotification = "WWDCWeekDidEndNotification"
let TranscriptIndexingDidStartNotification = "TranscriptIndexingDidStartNotification"
let TranscriptIndexingDidStopNotification = "TranscriptIndexingDidStopNotification"

@objc class WWDCDatabase: NSObject {
    
    private struct Constants {
        static var internalServiceURL = WWDCEnvironment.indexURL
        static let extraVideosURL = WWDCEnvironment.extraURL
        static let asciiServiceBaseURL = WWDCEnvironment.asciiWWDCURL
    }

    class var sharedDatabase: WWDCDatabase {
        return _sharedWWDCDatabase
    }
    
    override init() {
        super.init()
        
        configureRealm()
    }
    
    private let bgThread = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0)
    private var backgroundOperationQueue = NSOperationQueue()
    
    var config: AppConfig! {
        didSet {
            guard config != nil else { return }
            
            #if DEBUG
                NSLog("Did fetch AppConfig")
            #endif
            
            wipe2016TechTalksVideos()
            updateSessionVideos()
            updateSchedule()
        }
    }
    
    // MARK: - Realm Configuration
    
    private let currentDBVersion = UInt64(6)
    
    private func configureRealm() {
        let realmConfiguration = Realm.Configuration(schemaVersion: currentDBVersion, migrationBlock: { migration, oldVersion in
            if oldVersion == 0 && self.currentDBVersion >= 5 {
                NSLog("Migrating data from version 0 to version \(self.currentDBVersion)")
                // app config must be invalidated for this version update
                migration.deleteData("AppConfig")
            }
        })
        
        Realm.Configuration.defaultConfiguration = realmConfiguration
    }
    
    lazy var realm = try! Realm()
    
    /// Use this to change properties of model objects **on the main thread**
    /// - Warning: if you try to change properties of model objects (such as Session) outside a `doChanges` block, an exception will be thrown
    func doChanges(block: () -> Void) {
        realm.beginWrite()
        block()
        try! realm.commitWrite()
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
        try! bgRealm.commitWrite()
    }
    
    // MARK: - State
    
    /// Whether transcripts are currently being indexed
    var isIndexingTranscripts = false {
        didSet {
            guard oldValue != isIndexingTranscripts else { return }
            
            let notificationName = isIndexingTranscripts ? TranscriptIndexingDidStartNotification : TranscriptIndexingDidStopNotification
            
            mainQ {
                NSNotificationCenter.defaultCenter().postNotificationName(notificationName, object: nil)
            }
        }
    }
    
    /// The progress when the transcripts are being downloaded/indexed
    var transcriptIndexingProgress: NSProgress? {
        didSet {
            isIndexingTranscripts = (transcriptIndexingProgress != nil)
            
            transcriptIndexingStartedCallback?()
        }
    }
    /// Called when transcript downloading/indexing starts,
    /// use `transcriptIndexingProgress` to track progress
    var transcriptIndexingStartedCallback: (() -> Void)?
    
    /// A callback to execute whenever new sessions are available
    /// - parameter newSessionKeys: The keys (uniqueId) for the new sessions
    var sessionListChangedCallback: ((newSessionKeys: [String]) -> Void)?
    
    // MARK: - Core Functionality
    
    /// This is the main "sync" function
    /// #### The following steps are performed when `refresh()` is called:
    /// 1. Check to see if the URL for Apple's service has changed and update app config accordingly
    /// 2. Call Apple's service to get the list of session videos
    /// 3. Parse the results and update the local database
    /// 4. Fetch and index transcripts from ASCIIWWDC
    func refresh() {
        downloadAppConfigAndSyncDatabase()
    }
    
    /// Returns the list of sessions available sorted by year and session id
    /// - Warning: can only be used from the main thread
    var standardSessionList: Results<Session> {
        return realm.objects(Session.self).sorted(sortDescriptorsForSessionList)
    }
    
    /// #### The best sort descriptors for the list of videos
    /// Orders the videos by year (descending) and session number (ascending)
    lazy var sortDescriptorsForSessionList: [SortDescriptor] = [SortDescriptor(property: "year", ascending: false), SortDescriptor(property: "id", ascending: true)]
    
    private let manager = Alamofire.Manager(configuration: NSURLSessionConfiguration.ephemeralSessionConfiguration())
    
    /// This method downloads the app config from the server and sets It in self, which makes the app download the videos and schedule from the servers specified in the config
    private func downloadAppConfigAndSyncDatabase() {
        manager.request(.GET, Constants.internalServiceURL).response { _, _, data, error in
            guard let jsonData = data else {
                print("No data returned from internal server!")
                return
            }
            
            let configJSON = JSON(data: jsonData)
            
            let fetchedConfig = AppConfigAdapter.adapt(configJSON)
            
            let existingConfig = self.realm.objects(AppConfig.self).last
            
            // if the fetched config from the service is equal to the config in the database, don't bother updating It
            guard !fetchedConfig.isEqualToConfig(existingConfig) else {
                self.config = existingConfig
                return
            }
            
            if fetchedConfig.isWWDCWeek {
                mainQ {
                    #if DEBUG
                        print("WWDC week started")
                    #endif
                    NSNotificationCenter.defaultCenter().postNotificationName(WWDCWeekDidStartNotification, object: nil)
                }
            } else {
                mainQ {
                    #if DEBUG
                        print("WWDC week ended")
                    #endif
                    NSNotificationCenter.defaultCenter().postNotificationName(WWDCWeekDidEndNotification, object: nil)
                }
            }
            
            print("AppConfig changed")
            
            // replace configuration on the database with the new configuration
            self.realm.beginWrite()
            do {
                if let existingConfig = existingConfig {
                    self.realm.delete(existingConfig)
                }
                
                self.realm.add(fetchedConfig)
                
                try self.realm.commitWrite()
                
                self.config = fetchedConfig
            } catch let error {
                NSLog("Unable to save new configuration: \(error)")
            }
        }
    }
    
    private func wipe2016TechTalksVideos() {
        do {
            try realm.write {
                realm.delete(realm.objects(Session.self).filter("id > 10000"))
            }
        } catch let error {
            NSLog("Error deleting tech talks videos: \(error)")
        }
    }
    
    private func updateSessionVideos() {
        #if DEBUG
            NSLog("Updating videos...")
        #endif
        
        manager.request(.GET, config.videosURL).response { [weak self] _, _, data, error in
            guard let weakSelf = self else { return }
            
            dispatch_async(weakSelf.bgThread) {
                let backgroundRealm = try! Realm()
                
                guard let jsonData = data else {
                    print("No data returned from Apple's (session videos) server!")
                    return
                }
                
                let json = JSON(data: jsonData)
                
                var newVideosAvailable = true
                
                mainQS {
                    // check if the videos have been updated since the last fetch
                    if json["updated"].stringValue == weakSelf.config.videosUpdatedAt && !weakSelf.config.shouldIgnoreCache {
                        #if DEBUG
                            NSLog("Video list did not change")
                        #endif
                        newVideosAvailable = false
                    } else {
                        try! weakSelf.realm.write { weakSelf.config.videosUpdatedAt = json["updated"].stringValue }
                    }
                }
                
                guard newVideosAvailable else {
                    self?.reloadTranscriptsIfNeeded()
                    return
                }
                
                guard let sessionsArray = json["sessions"].array else {
                    #if DEBUG
                        NSLog("Could not parse array of videos")
                    #endif
                    return
                }
                
                var newSessionKeys: [String] = []
                
                // create and store/update each video
                for jsonSession in sessionsArray {
                    // ignored videos from 2016 without a duration specified
                    if jsonSession["duration"].intValue == 0 && jsonSession["year"].intValue > 2015 { continue }
                    
                    let session = SessionAdapter.adapt(jsonSession)
                    
                    if let existingSession = backgroundRealm.objectForPrimaryKey(Session.self, key: session.uniqueId) {
                        if !existingSession.isSemanticallyEqualToSession(session) {
                            // something about this session has changed, update
                            newSessionKeys.append(session.uniqueId)
                            
                            backgroundRealm.beginWrite()
                            session.favorite = existingSession.favorite
                            session.downloaded = existingSession.downloaded
                            session.progress = existingSession.progress
                            session.currentPosition = existingSession.currentPosition
                            do {
                                try backgroundRealm.commitWrite()
                            } catch let error {
                                NSLog("Error restoring properties for session \(session.uniqueId): \(error)")
                            }
                            
                        } else {
                            // there's nothing new about this session
                            continue;
                        }
                    } else {
                        newSessionKeys.append(session.uniqueId)
                    }
                    
                    if WWDCEnvironment.yearsToIgnoreTranscript.contains(session.year) {
                        newSessionKeys.remove(session.uniqueId)
                    }
                    
                    backgroundRealm.beginWrite()
                    
                    backgroundRealm.add(session, update: true)
                    
                    do {
                        try backgroundRealm.commitWrite()
                    } catch let error {
                        NSLog("Unable to commit session write: \(error)")
                    }
                }
                
                #if os(OSX)
                weakSelf.indexTranscriptsForSessionsWithKeys(newSessionKeys)
                #endif
                
                mainQ { weakSelf.sessionListChangedCallback?(newSessionKeys: newSessionKeys) }
            }
        }
    }
    
    private func updateSchedule() {
        #if DEBUG
            NSLog("Updating schedule...")
        #endif
        
        guard config.scheduleEnabled else { return }
        
        manager.request(.GET, config.sessionsURL).response { [weak self] _, _, data, error in
            guard let weakSelf = self else { return }
            
            dispatch_async(weakSelf.bgThread) {
                let backgroundRealm = try! Realm()
                
                guard let jsonData = data else {
                    print("No data returned from Apple's (session schedule) server!")
                    return
                }
                
                let json = JSON(data: jsonData)
                
                guard let tracksArray = json["response"]["tracks"].array else {
                    print("Could not parse array of tracks")
                    return
                }
                
                tracksArray.forEach({ jsonTrack in
                    let track = Track(json: jsonTrack)
                    backgroundRealm.beginWrite()
                    backgroundRealm.add(track, update: true)
                    do {
                        try backgroundRealm.commitWrite()
                    } catch let error {
                        NSLog("Error writing track \(track.name) to realm: \(error)")
                    }
                })
                
                guard let sessionsArray = json["response"]["sessions"].array else {
                    print("Could not parse array of sessions")
                    return
                }
                
                sessionsArray.forEach { jsonScheduledSession in
                    let scheduledSession = ScheduledSession(json: jsonScheduledSession)
                    
                    if scheduledSession.type.lowercaseString == "video" {
                        scheduledSession.startsAt = NSDate.distantFuture()
                    }
                    
                    if let trackName = jsonScheduledSession["track"].string {
                        scheduledSession.track = backgroundRealm.objectForPrimaryKey(Track.self, key: trackName)
                    }
                    
                    if let existingSession = backgroundRealm.objectForPrimaryKey(ScheduledSession.self, key: scheduledSession.uniqueId) {
                        // do not update semantically equal scheduled sessions
                        guard !existingSession.isSemanticallyEqualToScheduledSession(scheduledSession) else { return }
                    }
                    
                    backgroundRealm.beginWrite()
                    backgroundRealm.add(scheduledSession, update: true)
                    do {
                        try backgroundRealm.commitWrite()
                    } catch let error {
                        NSLog("Error writing scheduled session \(scheduledSession.uniqueId) to realm: \(error)")
                    }
                }
                
                mainQ {
                    weakSelf.sessionListChangedCallback?(newSessionKeys: [])
                }
            }
        }
    }
    
    func indexTranscriptsForSessionsWithKeys(sessionKeys: [String]) {
        guard !isIndexingTranscripts else { return }
        guard sessionKeys.count > 0 else { return }
        
        transcriptIndexingProgress = NSProgress(totalUnitCount: Int64(sessionKeys.count))
        backgroundOperationQueue.underlyingQueue = bgThread
        backgroundOperationQueue.name = "WWDCDatabase background"
        
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
        manager.request(.GET, url, parameters: nil, encoding: .JSON, headers: headers).response { _, response, data, error in
            guard let jsonData = data else {
                print("No data returned from ASCIIWWDC for session \(session.uniqueId)")
                return
            }
            
            self.backgroundOperationQueue.addOperationWithBlock {
                do {
                    let bgRealm = try Realm()
                    
                    guard let session = bgRealm.objectForPrimaryKey(Session.self, key: sessionKey) else { return }
                    
                    let transcript = TranscriptAdapter.adapt(JSON(data: jsonData))
                    transcript.session = session
                    
                    bgRealm.beginWrite()
                    bgRealm.add(transcript)
                    session.transcript = transcript
                    
                    try bgRealm.commitWrite()
                    
                    self.transcriptIndexingProgress?.completedUnitCount += 1
                } catch let error {
                    NSLog("Error indexing transcript for session \(sessionKey): \(error)")
                }
                
                if let progress = self.transcriptIndexingProgress {
                    #if DEBUG
                    NSLog("Completed: \(progress.completedUnitCount) Total: \(progress.totalUnitCount)")
                    #endif
                    
                    if progress.completedUnitCount >= progress.totalUnitCount - 1 {
                        mainQ {
                            #if DEBUG
                                NSLog("Transcript indexing finished")
                            #endif
                            self.isIndexingTranscripts = false
                        }
                    }
                }
            }
        }
    }
    
    private func reloadTranscriptsIfNeeded() {
        do {
            let bgRealm = try Realm()
            let validYears = WWDCEnvironment.reloadableYears
            let sessionKeys = bgRealm.objects(Session.self).filter({ validYears.contains($0.year) && $0.transcript == nil }).map({ $0.uniqueId })
            self.indexTranscriptsForSessionsWithKeys(sessionKeys)
        } catch {
            print("Error reloading transcripts: \(error)")
        }
    }
    
    /// Update downloaded flag on the database for the session with the specified URL
    func updateDownloadedStatusForSessionWithURL(url: String, downloaded: Bool) {
        backgroundOperationQueue.addOperationWithBlock {
            do {
                let bgRealm = try Realm()
                if let session = bgRealm.objects(Session.self).filter("hdVideoURL = %@", url).first {
                    do {
                        try bgRealm.write {
                            session.downloaded = downloaded
                        }
                    } catch _ {
                        print("Error updating downloaded flag for session with url \(url)")
                    }
                }
            } catch let error {
                print("Realm error \(error)")
            }
        }
    }
    
    /// Update downloaded flag on the database for the session with the specified filename
    func updateDownloadedStatusForSessionWithLocalFileName(filename: String, downloaded: Bool) {
        mainQ {
            guard let session = self.realm.objects(Session.self).filter("hdVideoURL contains %@", filename).first else {
                print("Session not found with local filename \(filename)")
                return
            }
            guard let url = session.hd_url else { return }
            
            self.updateDownloadedStatusForSessionWithURL(url, downloaded: downloaded)
        }
    }
    
}