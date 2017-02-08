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
    
    func testRoomsAdapter() {
        let json = getJson(from: "sessions")
        
        guard let roomsArray = json["response"]["rooms"].array else {
            XCTFail("Sessions.json fixture doesn't have a \"rooms\" array")
            fatalError()
        }
        
        let result = RoomsJSONAdapter().adapt(roomsArray)
        
        switch result {
        case .error(let error):
            XCTFail(error.localizedDescription)
        case .success(let rooms):
            XCTAssertEqual(rooms.count, 29)
            
            XCTAssertEqual(rooms[0].name, "Bill Graham Civic Auditorium")
            XCTAssertEqual(rooms[0].mapName, "BGCA")
            XCTAssertEqual(rooms[0].floor, "billGraham")
            
            XCTAssertEqual(rooms[28].name, "Recharge Lounge")
            XCTAssertEqual(rooms[28].mapName, "Lounge-Recharge")
            XCTAssertEqual(rooms[28].floor, "floor3")
        }
    }
    
    func testTracksAdapter() {
        let json = getJson(from: "sessions")
        
        guard let tracksArray = json["response"]["tracks"].array else {
            XCTFail("Sessions.json fixture doesn't have a \"tracks\" array")
            fatalError()
        }
        
        let result = TracksJSONAdapter().adapt(tracksArray)
        
        switch result {
        case .error(let error):
            XCTFail(error.localizedDescription)
        case .success(let tracks):
            XCTAssertEqual(tracks.count, 8)
            
            XCTAssertEqual(tracks[0].name, "Featured")
            XCTAssertEqual(tracks[0].lightColor, "#9E9E9E")
            XCTAssertEqual(tracks[0].lightBackgroundColor, "#32353D")
            XCTAssertEqual(tracks[0].darkColor, "#32353D")
            XCTAssertEqual(tracks[0].titleColor, "#D9D9DD")
            
            XCTAssertEqual(tracks[7].name, "Distribution")
            XCTAssertEqual(tracks[7].lightColor, "#B0619E")
            XCTAssertEqual(tracks[7].lightBackgroundColor, "#373049")
            XCTAssertEqual(tracks[7].darkColor, "#373049")
            XCTAssertEqual(tracks[7].titleColor, "#F5BEFF")
        }
    }

    func testKeywordsAdapter() {
        let json = getJson(from: "sessions")
        
        guard let keywordsArray = json["response"]["sessions"][0]["keywords"].array else {
            XCTFail("Couldn't find a session in sessions.json with an array of keywords")
            fatalError()
        }
        
        let result = KeywordsJSONAdapter().adapt(keywordsArray)
        
        switch result {
        case .error(let error):
            XCTFail(error.localizedDescription)
        case .success(let keywords):
            XCTAssertEqual(keywords.count, 10)
            XCTAssertEqual(keywords.map({ $0.name }), [
                "audio",
                "editing",
                "export",
                "hls",
                "http live streaming",
                "imaging",
                "media",
                "playback",
                "recording",
                "video"
                ]);
        }
    }

    func testFocusesAdapter() {
        let json = getJson(from: "sessions")
        
        guard let focusesArray = json["response"]["sessions"][0]["focus"].array else {
            XCTFail("Couldn't find a session in sessions.json with an array of focuses")
            fatalError()
        }
        
        let result = FocusesJSONAdapter().adapt(focusesArray)
        
        switch result {
        case .error(let error):
            XCTFail(error.localizedDescription)
        case .success(let focuses):
            XCTAssertEqual(focuses.count, 3)
            XCTAssertEqual(focuses.map({ $0.name }), [
                "iOS",
                "macOS",
                "tvOS"
                ]);
        }
    }
    
}
