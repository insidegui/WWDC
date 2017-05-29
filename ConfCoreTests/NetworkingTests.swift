//
//  NetworkingTests.swift
//  WWDC
//
//  Created by Guilherme Rambo on 21/02/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import XCTest
@testable import ConfCore

class NetworkingTests: XCTestCase {
    
    let client = AppleAPIClient(environment: .test)
    
    func testNewsItemEndpoint() {
        let exp = expectation(description: "News items response")
        
        client.fetchNewsItems { result in
            switch result {
            case .error(let error):
                XCTFail(error.localizedDescription)
            case .success(let items):
                XCTAssertEqual(items.count, 16)
            }
            
            exp.fulfill()
        }
        
        waitForExpectations(timeout: 10)
    }
    
    func testScheduleEndpoint() {
        let exp = expectation(description: "Schedule response")
        
        client.fetchSchedule { result in
            switch result {
            case .error(let error):
                XCTFail(error.localizedDescription)
            case .success(let response):
                XCTAssertEqual(response.tracks.count, 8)
                XCTAssertEqual(response.rooms.count, 29)
                XCTAssertEqual(response.instances.count, 316)
            }
            
            exp.fulfill()
        }
        
        waitForExpectations(timeout: 10)
    }
    
    func testSessionsAndAssetsEndpoint() {
        let exp = expectation(description: "Sessions and assets response")
        
        client.fetchSessions { result in
            switch result {
            case .error(let error):
                XCTFail(error.localizedDescription)
            case .success(let response):
                XCTAssertEqual(response.events.count, 5)
                XCTAssertEqual(response.sessions.count, 550)
                XCTAssertEqual(response.assets.count, 2947)
            }
            
            exp.fulfill()
        }
        
        waitForExpectations(timeout: 10)
    }
    
    func testLiveVideosEndpoint() {
        let exp = expectation(description: "Live videos response")
        
        client.fetchLiveVideoAssets { result in
            switch result {
            case .error(let error):
                XCTFail(error.localizedDescription)
            case .success(let assets):
                XCTAssertEqual(assets.count, 111)
            }
            
            exp.fulfill()
        }
        
        waitForExpectations(timeout: 10)
    }
    
}
