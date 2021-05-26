//
//  WWDCAgentInterface.swift
//  WWDCAgent
//
//  Created by Guilherme Rambo on 24/05/21.
//  Copyright © 2021 Guilherme Rambo. All rights reserved.
//

import Foundation

@objc protocol WWDCAgentInterface: AnyObject {
    func testAgentConnection(with completion: @escaping (Bool) -> Void)
    func searchForSessions(matching predicate: NSPredicate, completion: @escaping ([WWDCSessionXPCObject]) -> Void)
    
    func revealVideo(with id: String, completion: @escaping (Bool) -> Void)
    
    func toggleFavorite(for videoId: String, completion: @escaping (Bool) -> Void)
    func toggleWatched(for videoId: String, completion: @escaping (Bool) -> Void)
    
    func startDownload(for videoId: String, completion: @escaping (Bool) -> Void)
    func stopDownload(for videoId: String, completion: @escaping (Bool) -> Void)
}
