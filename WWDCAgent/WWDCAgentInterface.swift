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
    
    func fetchFavoriteSessions(for event: String?, completion: @escaping ([String]) -> Void)
    func fetchDownloadedSessions(for event: String?, completion: @escaping ([String]) -> Void)
    func fetchWatchedSessions(for event: String?, completion: @escaping ([String]) -> Void)
    func fetchUnwatchedSessions(for event: String?, completion: @escaping ([String]) -> Void)
    
    func revealVideo(with id: String, completion: @escaping (Bool) -> Void)
    
    func setFavorite(_ isFavorite: Bool, for videoId: String, completion: @escaping (Bool) -> Void)
    func setWatched(_ watched: Bool, for videoId: String, completion: @escaping (Bool) -> Void)
    
    func startDownload(for videoId: String, completion: @escaping (Bool) -> Void)
    func stopDownload(for videoId: String, completion: @escaping (Bool) -> Void)
}
