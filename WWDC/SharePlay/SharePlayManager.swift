//
//  SharePlayManager.swift
//  WWDC
//
//  Created by Guilherme Rambo on 11/06/21.
//  Copyright © 2021 Guilherme Rambo. All rights reserved.
//

import Foundation
import GroupActivities
import Combine
import ConfCore
import OSLog

final class SharePlayManager: ObservableObject, Logging, @unchecked Sendable {
    
    enum State {
        case idle
        case joining
        case starting
        case session(GroupSession<WatchWWDCActivity>)
    }
    
    @Published private(set) var state = State.idle
    
    static let log = makeLogger()
    
    private let observer = GroupStateObserver()
    
    static let shared = SharePlayManager()
    
    @Published private(set) var canStartSharePlay = false {
        didSet {
            log.debug("canStartSharePlay: \(self.canStartSharePlay, format: .answer)")
        }
    }
    
    private lazy var cancellables = Set<AnyCancellable>()
    private lazy var tasks = Set<Task<(), Never>>()
    
    @Published private(set) var currentActivity: WatchWWDCActivity?

    func startObservingState() {
        log.debug(#function)
        
        observer.$isEligibleForGroupSession.sink { newValue in
            self.canStartSharePlay = newValue
        }.store(in: &cancellables)
        
        let task = Task.detached {
            for await session in WatchWWDCActivity.sessions() {
                self.cancellables.removeAll()
                
                self.log.debug("Got new session in")
                
                session.$state.sink { state in
                    guard case .invalidated = state else { return }
                    
                    DispatchQueue.main.async { self.state = .idle }
                    self.cancellables.removeAll()
                }.store(in: &self.cancellables)

                session.join()
                
                session.$activity.sink { newActivity in
                    self.log.debug("New activity: \(String(describing: newActivity))")
                    
                    DispatchQueue.main.async { self.currentActivity = newActivity }
                }.store(in: &self.cancellables)
                
                self.state = .session(session)
            }
        }
        
        tasks.insert(task)
    }
    
    func startActivity(for session: Session) {
        log.debug(#function)
        
        state = .joining
        
        let activity = WatchWWDCActivity(with: session)
        
        Task {
            let result = await activity.prepareForActivation()
            
            switch result {
            case .activationPreferred:
                log.debug("Activating activity")

                do {
                    if try await activity.activate() {
                        log.debug("Activity activated")
                        
                        state = .starting
                    } else {
                        log.error("Activity did not activate")
                        
                        state = .idle
                    }
                } catch {
                    log.error("Failed to activate activity: \(String(describing: error), privacy: .public)")
                    
                    state = .idle
                }
            case .activationDisabled:
                log.error("Activity activation disabled")
                
                state = .idle
            case .cancelled:
                log.error("Activity activation cancelled")
                
                state = .idle
            @unknown default:
                log.fault("prepareForActivation resulted in unknown case")
                assertionFailure("Unknown case")
                
                state = .idle
            }
        }
    }
    
    func leaveActivity() {
        guard case .session(let session) = state else { return }
        
        session.leave()
    }

}
