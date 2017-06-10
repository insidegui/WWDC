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

            // Lab
            XCTAssertNotNil(instances[0].session)
            XCTAssertEqual(instances[0].session?.number, "5080")
            XCTAssertEqual(instances[0].session?.title, "AVFoundation / AVKit Lab")
            XCTAssertEqual(instances[0].session?.trackName, "Media")
            XCTAssertEqual(instances[0].session?.summary, "AVFoundation is a powerful framework for all types of media operations, including capture, editing, playback, and export. Built on AVFoundation, AVKit offers a fully featured and intuitive user interface for interaction with media in apps. Get one-on-one technical guidance from Apple engineers about using AVFoundation and AVKit in your apps. Bring your code and your questions.")
            XCTAssertEqual(instances[0].session?.focuses.count, 3)
            XCTAssertEqual(instances[0].session?.focuses[0].name, "iOS")
            XCTAssertEqual(instances[0].session?.focuses[1].name, "macOS")
            XCTAssertEqual(instances[0].session?.focuses[2].name, "tvOS")
            XCTAssertEqual(instances[0].identifier, "2016-5080")
            XCTAssertEqual(instances[0].number, "5080")
            XCTAssertEqual(instances[0].sessionType, 1)
            XCTAssertEqual(instances[0].keywords.count, 10)
            XCTAssertEqual(instances[0].keywords.first?.name, "audio")
            XCTAssertEqual(instances[0].keywords.last?.name, "video")
            XCTAssertEqual(instances[0].startTime, Date(timeIntervalSince1970: 1466020800))
            XCTAssertEqual(instances[0].endTime, Date(timeIntervalSince1970: 1466031600))

            // Session
            XCTAssertNotNil(instances[2].session)
            XCTAssertEqual(instances[2].session?.number, "301")
            XCTAssertEqual(instances[2].session?.title, "Introducing Expanded Subscriptions in iTunes Connect")
            XCTAssertEqual(instances[2].session?.trackName, "Distribution")
            XCTAssertEqual(instances[2].session?.summary, "See what's new in subscriptions. Learn how our improvements give you more flexibility and control over pricing, and provide powerful incentives to engage and retain your customers.")
            XCTAssertEqual(instances[2].session?.focuses.count, 3)
            XCTAssertEqual(instances[2].session?.focuses[0].name, "iOS")
            XCTAssertEqual(instances[2].session?.focuses[1].name, "macOS")
            XCTAssertEqual(instances[2].session?.focuses[2].name, "tvOS")
            XCTAssertEqual(instances[2].identifier, "2016-301")
            XCTAssertEqual(instances[2].number, "301")
            XCTAssertEqual(instances[2].sessionType, 0)
            XCTAssertEqual(instances[2].keywords.count, 2)
            XCTAssertEqual(instances[2].keywords.first?.name, "iap")
            XCTAssertEqual(instances[2].keywords.last?.name, "subscription")
            XCTAssertEqual(instances[2].startTime, Date(timeIntervalSince1970: 1465945200))
            XCTAssertEqual(instances[2].endTime, Date(timeIntervalSince1970: 1465947600))
        }
    }

    func testNewsAndPhotoAdapters() {
        let json = getJson(from: "news")

        guard let newsArray = json["items"].array else {
            XCTFail("Couldn't find an array of items in news.json")
            fatalError()
        }

        let result = NewsItemsJSONAdapter().adapt(newsArray)

        switch result {
        case .error(let error):
            XCTFail(error.localizedDescription)
        case .success(let items):
            XCTAssertEqual(items.count, 16)

            // Regular news
            XCTAssertEqual(items[0].identifier, "991DF480-4435-4930-B0BC-8F75EFB85002")
            XCTAssertEqual(items[0].title, "Welcome")
            XCTAssertEqual(items[0].body, "We’re looking forward to an exciting week at the Apple Worldwide Developers Conference. Use this app to stream session videos, browse the conference schedule, mark schedule items as favorites, keep up with the latest conference news, and view maps of Moscone West.")
            XCTAssertEqual(items[0].date, Date(timeIntervalSince1970: 1464973210))

            // Photo gallery
            XCTAssertEqual(items[5].identifier, "047E4F0B-2B8C-499A-BB23-F2CFDB3EB730")
            XCTAssertEqual(items[5].title, "Scholarship Winners Get the Excitement Started")
            XCTAssertEqual(items[5].body, "")
            XCTAssertEqual(items[5].date, Date(timeIntervalSince1970: 1465833604))
            XCTAssertEqual(items[5].photos[0].identifier, "6F3D98B4-71A9-4321-9D4E-974346E784FD")
            XCTAssertEqual(items[5].photos[0].representations[0].width, 256)
            XCTAssertEqual(items[5].photos[0].representations[0].remotePath, "6F3D98B4-71A9-4321-9D4E-974346E784FD/256.jpeg")
        }
    }

    func testTranscriptsAdapter() {
        let json = getJson(from: "transcript")

        let result = TranscriptsJSONAdapter().adapt(json)

        switch result {
        case .error(let error):
            XCTFail(error.localizedDescription)
        case .success(let transcript):
            XCTAssertEqual(transcript.identifier, "2014-101")
            XCTAssertEqual(transcript.fullText.characters.count, 92023)
            XCTAssertEqual(transcript.annotations.count, 2219)
            XCTAssertEqual(transcript.annotations.first!.timecode, 0.506)
            XCTAssertEqual(transcript.annotations.first!.body, "[ Silence ]")
        }
    }
    
}
