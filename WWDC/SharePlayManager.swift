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

@available(macOS 12.0, *)
final class SharePlayManager: ObservableObject {
    
    enum State {
        case idle
        case joining
        case starting
        case session(GroupSession<WatchWWDCActivity>)
    }
    
    @Published private(set) var state = State.idle
    
    static let subsystemName = "io.wwdc.app.SharePlay"
    
    private let logger = Logger(subsystem: SharePlayManager.subsystemName, category: String(describing: SharePlayManager.self))
    
    private let observer = GroupStateObserver()
    
    static let shared = SharePlayManager()
    
    @Published private(set) var canStartSharePlay = false {
        didSet {
            guard canStartSharePlay != oldValue else { return }
            
            logger.debug("canStartSharePlay = \(self.canStartSharePlay)")
        }
    }
    
    private lazy var cancellables = Set<AnyCancellable>()
    private lazy var tasks = Set<Task.Handle<(), Never>>()
    
    @Published private(set) var currentActivity: WatchWWDCActivity?

    @MainActor
    func startObservingState() {
        observer.$isEligibleForGroupSession.assign(to: &$canStartSharePlay)
        
        let task = detach {
            for await session in WatchWWDCActivity.sessions() {
                self.cancellables.removeAll()
                
                self.logger.debug("Got new session in")
                
                session.$state.sink { state in
                    guard case .invalidated = state else { return }
                    
                    self.state = .idle
                    self.cancellables.removeAll()
                }.store(in: &self.cancellables)

                session.join()
                
                session.$activity.sink { newActivity in
                    self.logger.debug("New activity: \(String(describing: newActivity))")
                    
                    self.currentActivity = newActivity
                }.store(in: &self.cancellables)
                
                self.state = .session(session)
            }
        }
        
        tasks.insert(task)
    }
    
    @MainActor
    func startActivity(for session: Session) {
        logger.debug(#function)
        
        state = .joining
        
        let activity = WatchWWDCActivity(with: session)
        
        async {
            let result = await activity.prepareForActivation()
            
            switch result {
            case .activationPreferred:
                logger.debug("Activating activity")
                
                activity.activate()
                
                state = .starting
            case .activationDisabled:
                logger.error("Activity activation disabled")
                
                state = .idle
            case .cancelled:
                logger.error("Activity activation cancelled")
                
                state = .idle
            @unknown default:
                logger.fault("prepareForActivation resulted in unknown case")
                assertionFailure("Unknown case")
                
                state = .idle
            }
        }
    }

}
