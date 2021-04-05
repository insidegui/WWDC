//
//  DecodingTests.swift
//  WWDC
//
//  Created by Guilherme Rambo on 07/02/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import XCTest
@testable import ConfCore

class AdapterTests: XCTestCase {

    private let dateTimeFormatter: DateFormatter = DateFormatter.confCoreFormatter

    private func loadFixture<T: Decodable>(from filename: String, type: T.Type = T.self) -> T {
        guard let fileURL = Bundle(for: AdapterTests.self).url(forResource: filename, withExtension: "json") else {
            XCTFail("Unable to find URL for fixture named \(filename)")
            fatalError()
        }

        guard let data = try? Data(contentsOf: fileURL) else {
            XCTFail("Unable to load fixture named \(filename)")
            fatalError()
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .formatted(.confCoreFormatter)
            return try decoder.decode(type, from: data)
        } catch {
            XCTFail("Failed to load test fixture with error: \(error)")
            fatalError()
        }
    }

    func testEventsAdapter() {
        struct TestFixture: Decodable {
            let events: [Event]
        }

        let events = loadFixture(from: "contents", type: TestFixture.self).events

        XCTAssertEqual(events.count, 5)

        XCTAssertEqual(events[0].name, "WWDC 2017")
        XCTAssertEqual(events[0].identifier, "wwdc2017")
        XCTAssertEqual(events[0].isCurrent, true)

        XCTAssertEqual(events[4].name, "WWDC 2013")
        XCTAssertEqual(events[4].identifier, "wwdc2013")
        XCTAssertEqual(events[4].isCurrent, false)
    }

    func testRoomsAdapter() {
        struct TestFixture: Decodable {
            let rooms: [Room]
        }

        let rooms = loadFixture(from: "contents", type: TestFixture.self).rooms

        XCTAssertEqual(rooms.count, 35)

        XCTAssertEqual(rooms[0].identifier, "63")
        XCTAssertEqual(rooms[0].name, "Hall 3")

        XCTAssertEqual(rooms[34].identifier, "83")
        XCTAssertEqual(rooms[34].name, "San Pedro Square")
    }

    func testTracksAdapter() {
        struct TestFixture: Decodable {
            let tracks: [Track]
        }

        let tracks = loadFixture(from: "contents", type: TestFixture.self).tracks

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

    func testKeywordsAdapter() {
        struct TestFixture: Decodable {
            struct TestSession: Decodable {
                let keywords: [Keyword]
            }
            struct Response: Decodable {
                let sessions: [TestSession]
            }
            let response: Response
        }

        let keywords = loadFixture(from: "sessions", type: TestFixture.self).response.sessions[0].keywords

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

    func testFocusesAdapter() {
        struct TestFixture: Decodable {
            struct TestSession: Decodable {
                let focus: [Focus]
            }
            struct Response: Decodable {
                let sessions: [TestSession]
            }
            let response: Response
        }

        let focuses = loadFixture(from: "sessions", type: TestFixture.self).response.sessions[0].focus

        XCTAssertEqual(focuses.count, 3)
        XCTAssertEqual(focuses.map({ $0.name }), [
            "iOS",
            "macOS",
            "tvOS"
            ])
    }

    // TODO: disabled test, SessionAssetsJSONAdapter is not working
    func _testAssetsAdapter() {
        struct TestFixture: Decodable {
            let sessions: [SessionAsset]
        }

        let assets = loadFixture(from: "videos", type: TestFixture.self).sessions

        let flattenedAssets = assets.compactMap({ $0 })
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

    func testLiveAssetsAdapter() throws {
        let assets: LiveVideosWrapper = loadFixture(from: "videos_live")

        let sortedAssets = assets.liveAssets.sorted(by: { $0.sessionId < $1.sessionId })
        XCTAssertEqual(sortedAssets[0].assetType, SessionAssetType(rawValue: SessionAssetType.liveStreamVideo.rawValue))
        XCTAssertGreaterThan(sortedAssets[0].year, 2016)
        XCTAssertEqual(sortedAssets[0].sessionId, "wwdc2020-201")
        XCTAssertEqual(sortedAssets[0].remoteURL, "http://devstreaming.apple.com/videos/wwdc/2016/live/mission_ghub2yon5yewl2i/atv_mvp.m3u8")
    }

    func testSessionsAdapter() {
        struct TestFixture: Decodable {
            let contents: [Session]
        }

        let sessions = loadFixture(from: "contents", type: TestFixture.self).contents

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

    func testSessionInstancesAdapter() {
        struct TestFixture: Decodable {
            let contents: ConditionallyDecodableCollection<SessionInstance>
        }

        let instances = loadFixture(from: "contents", type: TestFixture.self).contents

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
        XCTAssertEqual(instances[0].eventIdentifier, "wwdc2017")

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

    func testNewsAndPhotoAdapters() throws {
        struct TestFixture: Decodable {
            let items: ConditionallyDecodableCollection<NewsItem>
        }

        let items = Array(loadFixture(from: "news", type: TestFixture.self).items)

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

    func testTranscriptsAdapter() {
        let transcript = loadFixture(from: "transcript", type: Transcript.self)

        XCTAssertEqual(transcript.identifier, "wwdc2014-101")
        XCTAssertEqual(transcript.fullText.count, 92023)
        XCTAssertEqual(transcript.annotations.count, 2219)
        XCTAssertEqual(transcript.annotations.first!.timecode, 0.506)
        XCTAssertEqual(transcript.annotations.first!.body, "[ Silence ]")
    }

    func testFeaturedSectionsAdapter() {
        struct TestFixture: Decodable {
            let sections: [FeaturedSection]
        }

        let sections = loadFixture(from: "layout", type: TestFixture.self).sections

        XCTAssertEqual(sections[0].order, -1)
        XCTAssertEqual(sections[0].format, FeaturedSectionFormat.curated)
        XCTAssertEqual(sections[0].title, "Creator's Favorites")
        XCTAssertEqual(sections[0].summary, "Rambo's favorite sessions")
        XCTAssertEqual(sections[0].colorA, "#3C5B72")
        XCTAssertEqual(sections[0].colorB, "#3D5B73")
        XCTAssertEqual(sections[0].colorC, "#ACBDCB")
        XCTAssertEqual(sections[0].author?.name, "Guilherme Rambo")
        XCTAssertEqual(sections[0].author?.bio, "Guilherme Rambo is the creator of the unofficial WWDC app for macOS")
        XCTAssertEqual(sections[0].author?.avatar, "https://pbs.twimg.com/profile_images/932637040474316801/mhtK0Y2u_400x400.jpg")
        XCTAssertEqual(sections[0].author?.url, "https://guilhermerambo.me")
        XCTAssertEqual(sections[0].content.count, 8)
        XCTAssertEqual(sections[0].content[0].sessionId, "wwdc2017-211")
        XCTAssertEqual(sections[0].content[1].sessionId, "wwdc2017-222")
        XCTAssertEqual(sections[0].content[0].essay?.count, 401)
        XCTAssertEqual(sections[0].content[0].bookmarks.count, 2)
        XCTAssertEqual(sections[0].content[0].bookmarks[0].body, "My favorite part")
        XCTAssertEqual(sections[0].content[0].bookmarks[0].timecode, 180.0)
        XCTAssertEqual(sections[0].content[0].bookmarks[0].isShared, true)
        XCTAssertEqual(sections[0].content[0].bookmarks[1].duration, 60.0)
    }

    func testConfigAdapter() {
        let config = loadFixture(from: "config", type: ConfigResponse.self)

        XCTAssertEqual(config.feeds.count, 4)

        XCTAssertEqual(config.feeds["en"]!.contents.url.absoluteString, "https://devimages-cdn.apple.com/wwdc-services/m5ec5ace/F1CF2B37-A0B5-4323-9E18-07283310EDCA/contents.json")
        XCTAssertEqual(config.feeds["en"]!.contents.etag, "\"3e9d59abf767fca51c271a1a651b265d\"")

        XCTAssertEqual(config.feeds["kor"]!.transcripts.url.absoluteString, "https://devimages-cdn.apple.com/wwdc-services/transcripts/manifests/transcript-manifest-kor.json")
        XCTAssertEqual(config.feeds["kor"]!.transcripts.etag, "\"42106fe22ddd57ef0620bbe42eacf164\"")

        XCTAssertNotNil(config.eventHero)
        XCTAssertEqual(config.eventHero?.identifier, "AB1C61AC-02EF-46A4-A16C-AD65A4D6289F")
        XCTAssertEqual(config.eventHero?.title, "Ready. Set. Code.")
        XCTAssertEqual(config.eventHero?.titleColor, "#FFFFFF")
        XCTAssertEqual(config.eventHero?.body, "Starting June 22, WWDC20 takes off. Get ready for the first global, all-online WWDC by turning on your notifications to get all the latest news, with updates for events and sessions. More announcements to come in June.")
        XCTAssertEqual(config.eventHero?.bodyColor, "#FFFFFF")
        XCTAssertEqual(config.eventHero?.backgroundImage, "https://devimages-cdn.apple.com/wwdc-services/images/wwdc20/v3-EFE0FCBF-4265-46D6-BBCD-85314EF768CE/BG-WWDCTab-Landscape.heic")
    }

}
