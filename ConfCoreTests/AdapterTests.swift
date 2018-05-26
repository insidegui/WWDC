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

    private let dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = confCoreDateFormat
        formatter.locale = Locale(identifier: "en-US")
        formatter.timeZone = TimeZone.current
        return formatter
    }()

    private func getJson(from filename: String) -> JSON {
        guard let fileURL = Bundle(for: AdapterTests.self).url(forResource: filename, withExtension: "json") else {
            XCTFail("Unable to find URL for fixture named \(filename)")
            fatalError()
        }

        guard let data = try? Data(contentsOf: fileURL), let json = try? JSON(data: data) else {
            XCTFail("Unable to load fixture named \(filename)")
            fatalError()
        }

        return json
    }

    func testEventsAdapter() {
        let json = getJson(from: "contents")

        guard let eventsArray = json["events"].array else {
            XCTFail("Sessions.json fixture doesn't have an \"events\" array")
            fatalError()
        }

        let result = EventsJSONAdapter().adapt(eventsArray)

        switch result {
        case .error(let error):
            XCTFail(error.localizedDescription)
        case .success(let events):
            XCTAssertEqual(events.count, 5)

            XCTAssertEqual(events[0].name, "WWDC 2017")
            XCTAssertEqual(events[0].identifier, "wwdc2017")
            XCTAssertEqual(events[0].isCurrent, true)

            XCTAssertEqual(events[4].name, "WWDC 2013")
            XCTAssertEqual(events[4].identifier, "wwdc2013")
            XCTAssertEqual(events[4].isCurrent, false)
        }
    }

    func testRoomsAdapter() {
        let json = getJson(from: "contents")

        guard let roomsArray = json["rooms"].array else {
            XCTFail("Sessions.json fixture doesn't have a \"rooms\" array")
            fatalError()
        }

        let result = RoomsJSONAdapter().adapt(roomsArray)

        switch result {
        case .error(let error):
            XCTFail(error.localizedDescription)
        case .success(let rooms):
            XCTAssertEqual(rooms.count, 35)

            XCTAssertEqual(rooms[0].identifier, "63")
            XCTAssertEqual(rooms[0].name, "Hall 3")

            XCTAssertEqual(rooms[34].identifier, "83")
            XCTAssertEqual(rooms[34].name, "San Pedro Square")
        }
    }

    func testTracksAdapter() {
        let json = getJson(from: "contents")

        guard let tracksArray = json["tracks"].array else {
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
            XCTAssertEqual(tracks[0].lightColor, "#3C5B72")
            XCTAssertEqual(tracks[0].lightBackgroundColor, "#d8dee3")
            XCTAssertEqual(tracks[0].darkColor, "#223340")
            XCTAssertEqual(tracks[0].titleColor, "#223B4D")

            XCTAssertEqual(tracks[7].name, "Distribution")
            XCTAssertEqual(tracks[7].lightColor, "#8C61A6")
            XCTAssertEqual(tracks[7].lightBackgroundColor, "#E8DFED")
            XCTAssertEqual(tracks[7].darkColor, "#35243E")
            XCTAssertEqual(tracks[7].titleColor, "#4C2B5F")
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
                ])
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
                ])
        }
    }

    // TODO: disabled test, SessionAssetsJSONAdapter is not working
    func _testAssetsAdapter() {
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

            XCTAssertEqual(flattenedAssets[0].assetType, SessionAssetType(rawValue: SessionAssetType.streamingVideo.rawValue))
            XCTAssertEqual(flattenedAssets[0].remoteURL, "http://devstreaming.apple.com/videos/wwdc/2016/210e4481b1cnwor4n1q/210/hls_vod_mvp.m3u8")
            XCTAssertEqual(flattenedAssets[0].year, 2016)
            XCTAssertEqual(flattenedAssets[0].sessionId, "210")

            XCTAssertEqual(flattenedAssets[1].assetType, SessionAssetType(rawValue: SessionAssetType.hdVideo.rawValue))
            XCTAssertEqual(flattenedAssets[1].remoteURL, "http://devstreaming.apple.com/videos/wwdc/2016/210e4481b1cnwor4n1q/210/210_hd_mastering_uikit_on_tvos.mp4")
            XCTAssertEqual(flattenedAssets[1].relativeLocalURL, "2016/210_hd_mastering_uikit_on_tvos.mp4")
            XCTAssertEqual(flattenedAssets[1].year, 2016)
            XCTAssertEqual(flattenedAssets[1].sessionId, "210")

            XCTAssertEqual(flattenedAssets[2].assetType, SessionAssetType(rawValue: SessionAssetType.sdVideo.rawValue))
            XCTAssertEqual(flattenedAssets[2].remoteURL, "http://devstreaming.apple.com/videos/wwdc/2016/210e4481b1cnwor4n1q/210/210_sd_mastering_uikit_on_tvos.mp4")
            XCTAssertEqual(flattenedAssets[2].relativeLocalURL, "2016/210_sd_mastering_uikit_on_tvos.mp4")
            XCTAssertEqual(flattenedAssets[2].year, 2016)
            XCTAssertEqual(flattenedAssets[2].sessionId, "210")

            XCTAssertEqual(flattenedAssets[3].assetType, SessionAssetType(rawValue: SessionAssetType.slides.rawValue))
            XCTAssertEqual(flattenedAssets[3].remoteURL, "http://devstreaming.apple.com/videos/wwdc/2016/210e4481b1cnwor4n1q/210/210_mastering_uikit_on_tvos.pdf")
            XCTAssertEqual(flattenedAssets[3].year, 2016)
            XCTAssertEqual(flattenedAssets[3].sessionId, "210")

            XCTAssertEqual(flattenedAssets[4].assetType, SessionAssetType(rawValue: SessionAssetType.webpage.rawValue))
            XCTAssertEqual(flattenedAssets[4].remoteURL, "https://developer.apple.com/wwdc16/210")
            XCTAssertEqual(flattenedAssets[4].year, 2016)
            XCTAssertEqual(flattenedAssets[4].sessionId, "210")

            XCTAssertEqual(flattenedAssets[5].assetType, SessionAssetType(rawValue: SessionAssetType.image.rawValue))
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
            let sortedAssets = assets.sorted(by: { $0.sessionId < $1.sessionId })
            XCTAssertEqual(sortedAssets[0].assetType, SessionAssetType(rawValue: SessionAssetType.liveStreamVideo.rawValue))
            XCTAssertGreaterThan(sortedAssets[0].year, 2016)
            XCTAssertEqual(sortedAssets[0].sessionId, "201")
            XCTAssertEqual(sortedAssets[0].remoteURL, "http://devstreaming.apple.com/videos/wwdc/2016/live/mission_ghub2yon5yewl2i/atv_mvp.m3u8")
        }
    }

    func testSessionsAdapter() {
        let json = getJson(from: "contents")

        guard let sessionsArray = json["contents"].array else {
            XCTFail("Couldn't find an array of sessions in contents.json")
            fatalError()
        }

        let result = SessionsJSONAdapter().adapt(sessionsArray)

        switch result {
        case .error(let error):
            XCTFail(error.localizedDescription)
        case .success(let sessions):
            XCTAssertEqual(sessions.count, 771)
            XCTAssertEqual(sessions[0].title, "Express Yourself!")
            XCTAssertEqual(sessions[0].trackName, "")
            XCTAssertEqual(sessions[0].number, "820")
            XCTAssertEqual(sessions[0].summary, "iMessage Apps help people easily create and share content, play games, and collaborate with friends without needing to leave the conversation. Explore how you can design iMessage apps and sticker packs that are perfectly suited for a deeply social context.")
            XCTAssertEqual(sessions[0].focuses[0].name, "iOS")
            XCTAssertEqual(sessions[0].related.count, 1)
            XCTAssertEqual(sessions[0].related[0].identifier, "17")
            XCTAssertEqual(sessions[0].related[0].type, RelatedResourceType.unknown.rawValue)
        }
    }

    func testSessionInstancesAdapter() {
        let json = getJson(from: "contents")

        guard let instancesArray = json["contents"].array else {
            XCTFail("Couldn't find an array of sessions in sessions.json")
            fatalError()
        }

        let result = SessionInstancesJSONAdapter().adapt(instancesArray)

        switch result {
        case .error(let error):
            XCTFail(error.localizedDescription)
        case .success(let instances):
            XCTAssertEqual(instances.count, 307)

            // Lab
            XCTAssertNotNil(instances[0].session)
            XCTAssertEqual(instances[0].session?.number, "8080")
            XCTAssertEqual(instances[0].session?.title, "User Interface Design By Appointment Lab")
            XCTAssertEqual(instances[0].session?.trackName, "")
            XCTAssertEqual(instances[0].session?.summary, "Get advice on making your apps simple to use and more visually compelling. Come prepared with a working prototype, development build or your released app. Appointments are required and limited to one per developer for the duration of the conference. You may request an appointment beginning at 7 a.m. for that day only. Appointments fill quickly.")
            XCTAssertEqual(instances[0].session?.focuses.count, 4)
            XCTAssertEqual(instances[0].session?.focuses[0].name, "iOS")
            XCTAssertEqual(instances[0].session?.focuses[1].name, "macOS")
            XCTAssertEqual(instances[0].session?.focuses[2].name, "tvOS")
            XCTAssertEqual(instances[0].identifier, "wwdc2017-8080")
            XCTAssertEqual(instances[0].number, "wwdc2017-8080")
            XCTAssertEqual(instances[0].sessionType, 1)
            XCTAssertEqual(instances[0].keywords.count, 0)
            XCTAssertEqual(instances[0].startTime, dateTimeFormatter.date(from: "2017-06-09T09:00:00-07:00"))
            XCTAssertEqual(instances[0].endTime, dateTimeFormatter.date(from: "2017-06-09T15:30:00-07:00"))
            XCTAssertEqual(instances[0].actionLinkPrompt, "Request appointment")
            XCTAssertEqual(instances[0].actionLinkURL, "https://developer.apple.com/go/?id=wwdc-consultations")

            // Session
            XCTAssertNotNil(instances[2].session)
            XCTAssertEqual(instances[2].session?.number, "4170")
            XCTAssertEqual(instances[2].session?.title, "Source Control, Simulator, Testing, and Continuous Integration with Xcode Lab")
            XCTAssertEqual(instances[2].session?.trackName, "")
            XCTAssertEqual(instances[2].session?.summary, "Learn how to get the most out of the new source control workflows in Xcode. Talk with Apple engineers about how to create a build and test strategy using Unit and UI Testing, testing with Simulator, or how to set up workflows using the new standalone Xcode Server. Bring your code and your questions.")
            XCTAssertEqual(instances[2].session?.focuses.count, 4)
            XCTAssertEqual(instances[2].session?.focuses[0].name, "iOS")
            XCTAssertEqual(instances[2].session?.focuses[1].name, "macOS")
            XCTAssertEqual(instances[2].session?.focuses[2].name, "tvOS")
            XCTAssertEqual(instances[2].identifier, "wwdc2017-4170")
            XCTAssertEqual(instances[2].number, "wwdc2017-4170")
            XCTAssertEqual(instances[2].sessionType, 1)
            XCTAssertEqual(instances[2].keywords.count, 0)
            XCTAssertEqual(instances[2].startTime, dateTimeFormatter.date(from: "2017-06-08T16:10:00-07:00"))
            XCTAssertEqual(instances[2].endTime, dateTimeFormatter.date(from: "2017-06-08T18:00:00-07:00"))
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
            XCTAssertEqual(transcript.identifier, "wwdc2014-101")
            XCTAssertEqual(transcript.fullText.count, 92023)
            XCTAssertEqual(transcript.annotations.count, 2219)
            XCTAssertEqual(transcript.annotations.first!.timecode, 0.506)
            XCTAssertEqual(transcript.annotations.first!.body, "[ Silence ]")
        }
    }

}
