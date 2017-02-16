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
    
    func testAssetsAdapter() {
        let json = getJson(from: "videos")
        
        guard let sessionsArray = json["sessions"].array else {
            XCTFail("Couldn't find an array of sessions in videos.json")
            fatalError()
        }
        
        let result = SessionAssetsJSONAdapter().adapt(sessionsArray)
        
        switch result {
        case .error(let error):
            XCTFail(error.localizedDescription)
        case .success(let assets):
            let flattenedAssets = assets.flatMap({ $0 })
            XCTAssertEqual(flattenedAssets.count, 2947)
            
            XCTAssertEqual(flattenedAssets[0].assetType, SessionAssetType.streamingVideo.rawValue)
            XCTAssertEqual(flattenedAssets[0].remoteURL, "http://devstreaming.apple.com/videos/wwdc/2016/210e4481b1cnwor4n1q/210/hls_vod_mvp.m3u8")
            XCTAssertEqual(flattenedAssets[0].year, 2016)
            XCTAssertEqual(flattenedAssets[0].sessionId, "210")
            
            XCTAssertEqual(flattenedAssets[1].assetType, SessionAssetType.hdVideo.rawValue)
            XCTAssertEqual(flattenedAssets[1].remoteURL, "http://devstreaming.apple.com/videos/wwdc/2016/210e4481b1cnwor4n1q/210/210_hd_mastering_uikit_on_tvos.mp4")
            XCTAssertEqual(flattenedAssets[1].relativeLocalURL, "2016/210_hd_mastering_uikit_on_tvos.mp4")
            XCTAssertEqual(flattenedAssets[1].year, 2016)
            XCTAssertEqual(flattenedAssets[1].sessionId, "210")
            
            XCTAssertEqual(flattenedAssets[2].assetType, SessionAssetType.sdVideo.rawValue)
            XCTAssertEqual(flattenedAssets[2].remoteURL, "http://devstreaming.apple.com/videos/wwdc/2016/210e4481b1cnwor4n1q/210/210_sd_mastering_uikit_on_tvos.mp4")
            XCTAssertEqual(flattenedAssets[2].relativeLocalURL, "2016/210_sd_mastering_uikit_on_tvos.mp4")
            XCTAssertEqual(flattenedAssets[2].year, 2016)
            XCTAssertEqual(flattenedAssets[2].sessionId, "210")
            
            XCTAssertEqual(flattenedAssets[3].assetType, SessionAssetType.slides.rawValue)
            XCTAssertEqual(flattenedAssets[3].remoteURL, "http://devstreaming.apple.com/videos/wwdc/2016/210e4481b1cnwor4n1q/210/210_mastering_uikit_on_tvos.pdf")
            XCTAssertEqual(flattenedAssets[3].year, 2016)
            XCTAssertEqual(flattenedAssets[3].sessionId, "210")
            
            XCTAssertEqual(flattenedAssets[4].assetType, SessionAssetType.webpage.rawValue)
            XCTAssertEqual(flattenedAssets[4].remoteURL, "https://developer.apple.com/wwdc16/210")
            XCTAssertEqual(flattenedAssets[4].year, 2016)
            XCTAssertEqual(flattenedAssets[4].sessionId, "210")
            
            XCTAssertEqual(flattenedAssets[5].assetType, SessionAssetType.image.rawValue)
            XCTAssertEqual(flattenedAssets[5].remoteURL, "http://devstreaming.apple.com/videos/wwdc/2016/210e4481b1cnwor4n1q/210/images/210_734x413.jpg")
            XCTAssertEqual(flattenedAssets[5].year, 2016)
            XCTAssertEqual(flattenedAssets[5].sessionId, "210")
        }
    }
    
    func testLiveAssetsAdapter() {
        let json = getJson(from: "videos_live")
        
        guard let sessionsDict = json["live_sessions"].dictionary else {
            XCTFail("Couldn't find a dictionary of live sessions in videos_live.json")
            fatalError()
        }
        
        let sessionsArray = sessionsDict.map { key, value -> JSON in
            var v = value
            v["sessionId"] = JSON.init(rawValue: key)!
            return v
        }
        
        let result = LiveVideosAdapter().adapt(sessionsArray)
     
        switch result {
        case .error(let error):
            XCTFail(error.localizedDescription)
        case .success(let assets):
            let sortedAssets = assets.sorted(by: { $0.0.sessionId < $0.1.sessionId })
            XCTAssertEqual(sortedAssets[0].assetType, SessionAssetType.liveStreamVideo.rawValue)
            XCTAssertGreaterThan(sortedAssets[0].year, 2016)
            XCTAssertEqual(sortedAssets[0].sessionId, "201")
            XCTAssertEqual(sortedAssets[0].remoteURL, "http://devstreaming.apple.com/videos/wwdc/2016/live/mission_ghub2yon5yewl2i/atv_mvp.m3u8")
        }
    }
    
    func testSessionsAdapter() {
        let json = getJson(from: "videos")
        
        guard let sessionsArray = json["sessions"].array else {
            XCTFail("Couldn't find an array of sessions in videos.json")
            fatalError()
        }
        
        let result = SessionsJSONAdapter().adapt(sessionsArray)
        
        switch result {
        case .error(let error):
            XCTFail(error.localizedDescription)
        case .success(let sessions):
            XCTAssertEqual(sessions.count, 550)
            XCTAssertEqual(sessions[0].title, "Mastering UIKit on tvOS")
            XCTAssertEqual(sessions[0].trackName, "App Frameworks")
            XCTAssertEqual(sessions[0].number, "210")
            XCTAssertEqual(sessions[0].summary, "Learn how to make your tvOS interface more dynamic, intuitive, and high-performing with tips and tricks learned in this session.")
            XCTAssertEqual(sessions[0].focuses[0].name, "tvOS")
        }
    }
    
    func testSessionInstancesAdapter() {
        let json = getJson(from: "sessions")
        
        guard let instancesArray = json["response"]["sessions"].array else {
            XCTFail("Couldn't find an array of sessions in sessions.json")
            fatalError()
        }
        
        let result = SessionInstancesJSONAdapter().adapt(instancesArray)
        
        switch result {
        case .error(let error):
            XCTFail(error.localizedDescription)
        case .success(let instances):
            XCTAssertEqual(instances.count, 316)
        }
    }
    
}
