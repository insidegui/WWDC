//
//  WWDCAgentService.swift
//  WWDCAgent
//
//  Created by Guilherme Rambo on 24/05/21.
//  Copyright © 2021 Guilherme Rambo. All rights reserved.
//

import Cocoa
import ConfCore
import Realm

@objc final class WWDCAgentService: NSObject {
    
    private let log = OSLog.agentLog(with: String(describing: WWDCAgentService.self))
    
    private let pupetteer = WWDCAppPuppeteer()
    
    private lazy var listener: NSXPCListener = {
        let l = NSXPCListener(machServiceName: "io.wwdc.app.WWDCAgent")
        
        l.delegate = self
        
        return l
    }()
    
    private var storage: Storage?
    private var syncEngine: SyncEngine?
    
    private let boot = Boot()
    
    func start() {
        boot.bootstrapDependencies(readOnly: false) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let dependencies):
                self.storage = dependencies.storage
                self.syncEngine = dependencies.syncEngine
                
                os_log("Bootstrapped successfully!", log: self.log, type: .default)
                
                self.startListening()
            case .failure(let error):
                os_log("Bootstrap failed: %{public}@", log: self.log, type: .error, String(describing: error))
            }
        }
    }
    
    private func startListening() {
        dispatchPrecondition(condition: .onQueue(.main))
        
        listener.resume()
        
        os_log("XPC service started", log: self.log, type: .default)
    }

}

extension WWDCAgentService: NSXPCListenerDelegate {
    
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        os_log("%{public}@ %{public}@", log: log, type: .debug, #function, newConnection)
        
        guard XPCConnectionValidator.shared.validate(newConnection) else {
            os_log("Refusing connection because the validation failed: %{public}@", log: self.log, type: .error, newConnection)
            return false
        }
        
        newConnection.exportedInterface = NSXPCInterface(with: WWDCAgentInterface.self)
        newConnection.exportedObject = self
        newConnection.resume()
        
        return true
    }
    
}

extension WWDCAgentService: WWDCAgentInterface {

    func testAgentConnection(with completion: @escaping (Bool) -> Void) {
        os_log("%{public}@", log: log, type: .debug, #function)
        
        completion(true)
    }
    
    // MARK: - Commands
    
    func setFavorite(_ isFavorite: Bool, for videoId: String, completion: @escaping (Bool) -> Void) {
        os_log("%{public}@", log: log, type: .debug, #function)
        
        pupetteer.sendCommand(isFavorite ? .favorite(videoId) : .unfavorite(videoId), completion: completion)
    }
    
    func setWatched(_ watched: Bool, for videoId: String, completion: @escaping (Bool) -> Void) {
        os_log("%{public}@", log: log, type: .debug, #function)
        
        pupetteer.sendCommand(watched ? .watch(videoId) : .unwatch(videoId), completion: completion)
    }
    
    func startDownload(for videoId: String, completion: @escaping (Bool) -> Void) {
        os_log("%{public}@", log: log, type: .debug, #function)
        
        pupetteer.sendCommand(.download(videoId), completion: completion)
    }
    
    func stopDownload(for videoId: String, completion: @escaping (Bool) -> Void) {
        os_log("%{public}@", log: log, type: .debug, #function)
        
        pupetteer.sendCommand(.cancelDownload(videoId), completion: completion)
    }
    
    func revealVideo(with id: String, completion: @escaping (Bool) -> Void) {
        os_log("%{public}@", log: log, type: .debug, #function)
        
        pupetteer.sendCommand(.revealVideo(id), completion: completion)
    }
    
    // MARK: - Session identifier fetching
    
    private func eventPredicate(for id: String) -> NSPredicate {
        NSPredicate(format: "eventIdentifier == %@", id)
    }
    
    private func andPredicateWithOptionalEventId(_ eventId: String?, _ predicate: NSPredicate) -> NSPredicate {
        if let id = eventId {
            return NSCompoundPredicate(andPredicateWithSubpredicates: [eventPredicate(for: id), predicate])
        } else {
            return predicate
        }
    }
    
    private func fetchSessionIdentifiers(for predicate: NSPredicate) -> [String] {
        guard let storage = storage else {
            os_log("Storage not available", log: self.log, type: .fault)
            return []
        }
        
        do {
            let realm = try Realm(configuration: storage.realmConfig)
            
            let identifiers = realm.objects(Session.self).filter(predicate).map({ $0.identifier })
            
            os_log("Found %{public}d session(s) matching the specified predicate (%@)", log: self.log, type: .debug, identifiers.count, String(describing: predicate))
            
            return Array(identifiers)
        } catch {
            os_log("Fetch failed: %{public}@", log: self.log, type: .error, String(describing: error))
            
            return []
        }
    }
    
    func fetchFavoriteSessions(for event: String?, completion: @escaping ([String]) -> Void) {
        os_log("%{public}@", log: log, type: .debug, #function)
        
        let predicate = NSPredicate(format: "SUBQUERY(favorites, $favorite, $favorite.isDeleted == 0).@count > 0")
        
        let sessionIdentifiers = fetchSessionIdentifiers(for: andPredicateWithOptionalEventId(event, predicate))
        
        completion(sessionIdentifiers)
    }
    
    func fetchDownloadedSessions(for event: String?, completion: @escaping ([String]) -> Void) {
        os_log("%{public}@", log: log, type: .debug, #function)
        
        let predicate = NSPredicate(format: "isDownloaded == 1 AND ANY assets.rawAssetType == \"WWDCSessionAssetTypeStreamingVideo\"")
        
        let sessionIdentifiers = fetchSessionIdentifiers(for: andPredicateWithOptionalEventId(event, predicate))
        
        completion(sessionIdentifiers)
    }
    
    func fetchWatchedSessions(for event: String?, completion: @escaping ([String]) -> Void) {
        os_log("%{public}@", log: log, type: .debug, #function)
        
        let predicate = NSPredicate(format: "(SUBQUERY(progresses, $progress, $progress.relativePosition >= \(Constants.watchedVideoRelativePosition)).@count > 0)")
        
        let sessionIdentifiers = fetchSessionIdentifiers(for: andPredicateWithOptionalEventId(event, predicate))
        
        completion(sessionIdentifiers)
    }
    
    func fetchUnwatchedSessions(for event: String?, completion: @escaping ([String]) -> Void) {
        os_log("%{public}@", log: log, type: .debug, #function)
        
        let predicate = NSPredicate(format: "(SUBQUERY(progresses, $progress, $progress.relativePosition < \(Constants.watchedVideoRelativePosition)).@count > 0 OR progresses.@count == 0)")
        
        let sessionIdentifiers = fetchSessionIdentifiers(for: andPredicateWithOptionalEventId(event, predicate))
        
        completion(sessionIdentifiers)
    }
}
