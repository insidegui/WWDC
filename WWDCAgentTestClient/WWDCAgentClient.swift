//
//  WWDCAgentClient.swift
//  WWDCAgentTestClient
//
//  Created by Guilherme Rambo on 24/05/21.
//  Copyright © 2021 Guilherme Rambo. All rights reserved.
//

import Cocoa
import Combine
import os.log

final class WWDCAgentClient: NSObject, ObservableObject {
    
    private let log = OSLog(subsystem: "io.wwdc.app.AgentClient", category: String(describing: WWDCAgentClient.self))
    
    @Published private(set) var isConnected = false
    @Published private(set) var searchResults: [WWDCSessionXPCObject] = []
    @Published var searchTerm: String = ""
    
    private var cancellables = Set<AnyCancellable>()
    
    override init() {
        super.init()
        
        $searchTerm.throttle(for: 0.3, scheduler: DispatchQueue.main, latest: true).sink { [weak self] term in
            self?.performSearch(with: term)
        }.store(in: &cancellables)
    }
    
    private lazy var connection: NSXPCConnection = {
        let c = NSXPCConnection(machServiceName: "io.wwdc.app.WWDCAgent", options: [])
        
        c.invalidationHandler = { [weak self] in
            DispatchQueue.main.async { self?.isConnected = false }
        }
        c.interruptionHandler = { [weak self] in
            DispatchQueue.main.async { self?.isConnected = false }
        }
        c.remoteObjectInterface = NSXPCInterface(with: WWDCAgentInterface.self)
        
        c.remoteObjectInterface?.setClasses(
            NSSet(array: [NSArray.self, WWDCSessionXPCObject.self]) as! Set<AnyHashable>,
            for: #selector(WWDCAgentInterface.searchForSessions(matching:completion:)),
            argumentIndex: 0,
            ofReply: true
        )
        
        return c
    }()
    
    private var agent: WWDCAgentInterface? {
        return connection.remoteObjectProxyWithErrorHandler { [weak self] error in
            print(error)
            DispatchQueue.main.async { self?.isConnected = false }
        } as? WWDCAgentInterface
    }
    
    func sendTestRequest(with completion: @escaping (Bool) -> Void) {
        agent?.testAgentConnection(with: { result in
            DispatchQueue.main.async { completion(result) }
        })
    }
    
    func performSearch(with term: String) {
        guard term.count >= 3 else {
            searchResults = []
            return
        }
        
        agent?.searchForSessions(matching: NSPredicate(format: "title contains[cd] %@ OR summary contains[cd] %@", term, term), completion: { [weak self] objects in
            DispatchQueue.main.async { self?.searchResults = objects }
        })
    }
    
    private var resumed = false
    
    func connect() {
        guard !resumed else { return }
        resumed = true
        
        connection.resume()
        
        isConnected = true
    }
    
    func toggleFavorite(for videoId: String) {
        os_log("%{public}@", log: log, type: .debug, #function)
        
        agent?.toggleFavorite(for: videoId, completion: { result in
            os_log("Result: %{public}@", log: self.log, type: .debug, String(describing: result))
        })
    }
    
    func toggleWatched(for videoId: String) {
        os_log("%{public}@", log: log, type: .debug, #function)
        
        agent?.toggleWatched(for: videoId, completion: { result in
            os_log("Result: %{public}@", log: self.log, type: .debug, String(describing: result))
        })
    }
    
    func startDownload(for videoId: String) {
        os_log("%{public}@", log: log, type: .debug, #function)
        
        agent?.startDownload(for: videoId, completion: { result in
            os_log("Result: %{public}@", log: self.log, type: .debug, String(describing: result))
        })
    }
    
    func stopDownload(for videoId: String) {
        os_log("%{public}@", log: log, type: .debug, #function)
        
        agent?.stopDownload(for: videoId, completion: { result in
            os_log("Result: %{public}@", log: self.log, type: .debug, String(describing: result))
        })
    }
    
    func revealVideo(with id: String) {
        os_log("%{public}@", log: log, type: .debug, #function)
        
        agent?.revealVideo(with: id, completion: { result in
            os_log("Result: %{public}@", log: self.log, type: .debug, String(describing: result))
        })
    }
    
}
