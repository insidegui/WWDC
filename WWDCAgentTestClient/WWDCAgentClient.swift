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
    
    static let allEventsToken = "(All Events)"
    
    @Published private(set) var isConnected = false
    @Published private(set) var searchResults: [String] = []
    @Published var filterEventId: String = WWDCAgentClient.allEventsToken
    
    private var eventId: String? { filterEventId == Self.allEventsToken ? nil : filterEventId }
    
    @Published var searchTerm: String = ""
    
    /// Whether the user has enabled the agent in the app.
    /// The app will also post the distributed notification "io.wwdc.app.AgentEnabledPreferenceChanged" when it's changed.
    var isAgentPreferenceEnabled: Bool {
        guard let defaults = UserDefaults(suiteName: "io.wwdc.app") else { return false }
        return defaults.bool(forKey: "isAgentEnabled")
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    override init() {
        super.init()
        
        os_log("Agent enabled preference is currently set to %{public}@", log: self.log, type: .debug, String(describing: isAgentPreferenceEnabled))
        
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(preferenceChanged),
            name: NSNotification.Name("io.wwdc.app.AgentEnabledPreferenceChanged"),
            object: nil,
            suspensionBehavior: .deliverImmediately
        )
    }
    
    @objc private func preferenceChanged(_ note: Notification) {
        os_log("Agent enabled preference changed to %{public}@", log: self.log, type: .debug, String(describing: isAgentPreferenceEnabled))
    }
    
    func fetchFavoriteIdentifiers() {
        agent?.fetchFavoriteSessions(for: eventId, completion: { [weak self] ids in
            DispatchQueue.main.async { self?.searchResults = ids }
        })
    }
    
    func fetchDownloadedIdentifiers() {
        agent?.fetchDownloadedSessions(for: eventId, completion: { [weak self] ids in
            DispatchQueue.main.async { self?.searchResults = ids }
        })
    }
    
    func fetchWatchedIdentifiers() {
        agent?.fetchWatchedSessions(for: eventId, completion: { [weak self] ids in
            DispatchQueue.main.async { self?.searchResults = ids }
        })
    }
    
    func fetchUnwatchedIdentifiers() {
        agent?.fetchUnwatchedSessions(for: eventId, completion: { [weak self] ids in
            DispatchQueue.main.async { self?.searchResults = ids }
        })
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

        return c
    }()
    
    private var agent: WWDCAgentInterface? {
        return connection.remoteObjectProxyWithErrorHandler { [weak self] error in
            DispatchQueue.main.async { self?.isConnected = false }
        } as? WWDCAgentInterface
    }
    
    func sendTestRequest(with completion: @escaping (Bool) -> Void) {
        agent?.testAgentConnection(with: { result in
            DispatchQueue.main.async { completion(result) }
        })
    }

    private var resumed = false
    
    func connect() {
        guard !resumed else { return }
        resumed = true
        
        connection.resume()
        
        isConnected = true
    }
    
    func setFavorite(_ isFavorite: Bool, for videoId: String) {
        os_log("%{public}@", log: log, type: .debug, #function)
        
        agent?.setFavorite(isFavorite, for: videoId, completion: { result in
            os_log("Result: %{public}@", log: self.log, type: .debug, String(describing: result))
        })
    }
    
    func setWatched(_ watched: Bool, for videoId: String) {
        os_log("%{public}@", log: log, type: .debug, #function)
        
        agent?.setWatched(watched, for: videoId, completion: { result in
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
