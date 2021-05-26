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

@objc final class WWDCAgentService: NSObject, WWDCAgentInterface {
    
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
        boot.bootstrapDependencies(readOnly: true) { [weak self] result in
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
    
    func testAgentConnection(with completion: @escaping (Bool) -> Void) {
        os_log("%{public}@", log: log, type: .debug, #function)
        
        completion(true)
    }
    
    func searchForSessions(matching predicate: NSPredicate, completion: @escaping ([WWDCSessionXPCObject]) -> Void) {
        guard let storage = storage else {
            assertionFailure("Attempted to search without a storage in place!")
            os_log("Attempted to search without a storage in place!", log: self.log, type: .fault)
            return
        }
        
        do {
            let realm = try Realm(configuration: storage.realmConfig)

            let objects = realm.objects(Session.self).filter(predicate)
            
            let output = Array(objects.map(WWDCSessionXPCObject.init))
            
            os_log("Search with %@ returned %{public}d item(s)", log: self.log, type: .debug, String(describing: predicate), output.count)
            
            completion(output)
        } catch {
            os_log("Search failed: %{public}@", log: self.log, type: .error, String(describing: error))
            
            completion([])
        }
    }
    
    func toggleFavorite(for videoId: String, completion: @escaping (Bool) -> Void) {
        os_log("%{public}@", log: log, type: .debug, #function)
        
        pupetteer.sendCommand(.toggleFavorite(videoId), completion: completion)
    }
    
    func toggleWatched(for videoId: String, completion: @escaping (Bool) -> Void) {
        os_log("%{public}@", log: log, type: .debug, #function)
        
        pupetteer.sendCommand(.toggleWatched(videoId), completion: completion)
    }
    
    func startDownload(for videoId: String, completion: @escaping (Bool) -> Void) {
        os_log("%{public}@", log: log, type: .debug, #function)
        
        pupetteer.sendCommand(.download(videoId), completion: completion)
    }
    
    func stopDownload(for videoId: String, completion: @escaping (Bool) -> Void) {
        os_log("%{public}@", log: log, type: .debug, #function)
        
        pupetteer.sendCommand(.cancelDownload(videoId), completion: completion)
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
