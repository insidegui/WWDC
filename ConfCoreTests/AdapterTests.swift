//
//  AdapterTests.swift
//  WWDC
//
//  Created by Guilherme Rambo on 07/02/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import XCTest
import SwiftyJSON
@testable import ConfCore

class AdapterTests: XCTestCase {

    private func getJson(from filename: String) -> JSON {
        guard let fileURL = Bundle(for: AdapterTests.self).url(forResource: filename, withExtension: "json") else {
            XCTFail("Unable to find URL for fixture named \(filename)")
            fatalError()
        }
        
        guard let data = try? Data(contentsOf: fileURL) else {
            XCTFail("Unable to load fixture named \(filename)")
            fatalError()
        }
        
        return JSON(data: data)
    }
    
    func testEventsAdapter() {
        let json = getJson(from: "sessions")
        
        guard let eventsArray = json["response"]["events"].array else {
            XCTFail("Sessions.json fixture doesn't have an \"events\" array")
            fatalError()
        }
        
        let result = EventsJSONAdapter().adapt(eventsArray)
        
        switch result {
        case .error(let error):
            XCTFail(error.localizedDescription)
        case .success(let events):
            XCTAssertEqual(events.count, 5)
            
            XCTAssertEqual(events[0].name, "WWDC 2016")
            XCTAssertEqual(events[0].identifier, "wwdc2016")
            XCTAssertEqual(events[0].isCurrent, true)
            
            XCTAssertEqual(events[4].name, "WWDC 2012")
            XCTAssertEqual(events[4].identifier, "wwdc2012")
            XCTAssertEqual(events[4].isCurrent, false)
        }
    }

}
