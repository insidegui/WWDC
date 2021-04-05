//
//  StorageTests.swift
//  ConfCoreTests
//
//  Created by Guilherme Rambo on 05/02/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import XCTest
import RealmSwift
@testable import ConfCore

class StorageTests: XCTestCase {

    private var realmConfig: Realm.Configuration!
    private var realm: Realm!
    private var storage: Storage!

    override func setUp() {
        super.setUp()

        storage = tryOrXCTFail(try Storage(Realm.makeInMemoryConfiguration()))
        realm = storage.realm
    }

    func test() {
        let contentsResponse = makeContentsResponse()

        let storeExpectation = expectation(description: "Store completion")

        storage.store(contentResult: .success(contentsResponse), completion: { _ in
            storeExpectation.fulfill()
        })

        waitForExpectations(timeout: 2)

        let event = realm.objects(Event.self).first
        XCTAssertNotNil(event)
        XCTAssertEqual(event?.sessions.count, 2)
        XCTAssertEqual(event?.sessions.first?.event.first?.name, event?.name)

        let track = realm.objects(Track.self).first
        XCTAssertNotNil(track)
        XCTAssertEqual(track?.sessions.count, 2)
        XCTAssertEqual(track?.sessions.first?.track.first?.name, track?.name)

        let focus = realm.objects(Focus.self).first
        XCTAssertNotNil(focus)
        XCTAssertEqual(focus?.sessions.count, 2)
        XCTAssertEqual(focus?.sessions.first?.focuses.first?.name, focus?.name)

        let room = realm.objects(Room.self).first
        XCTAssertNotNil(room)
        XCTAssertEqual(room?.instances.count, 1)
        XCTAssertEqual(room?.instances.first?.roomName, room?.name)

        let session = realm.objects(Session.self).first
        XCTAssertNotNil(session)
        XCTAssertEqual(session?.assets.count, 2)
        XCTAssertEqual(session?.favorites.count, 1)
        XCTAssertEqual(session?.bookmarks.count, 1)
        XCTAssertEqual(session?.focuses.count, 1)
        XCTAssertEqual(session?.track.count, 1)
        XCTAssertEqual(session?.event.count, 1)
        XCTAssertNotNil(session?.transcript)
        XCTAssertEqual(session?.related.count, 1)
        XCTAssertEqual(session?.related[0].identifier, "wwdc2014-206")
        XCTAssertEqual(session?.related[0].type, "WWDCSessionResourceTypeSession")
        XCTAssertNotNil(session?.related[0].session)
    }

    private func makeContentsResponse() -> ContentsResponse {
        let event = Event()
        event.identifier = "wwdc2014"
        event.name = "WWDC 2014"
        event.startDate = Date.distantPast
        event.endDate = Date.distantFuture

        let track = Track()
        track.name = "Developer Tools"
        track.darkColor = "#43342E"
        track.lightColor = "#E59053"
        track.titleColor = "#FFD78D"
        track.lightBackgroundColor = "#43342E"

        let focus = Focus()
        focus.name = "macOS"

        let room = Room()
        room.mapName = "Session-NobHill"
        room.name = "Nob Hill"
        room.floor = "floor2"

        let session = Session()

        session.identifier = "wwdc2014-415"
        session.number = "415"
        session.summary = "Xcode bots provide a seamless way to continually build, analyze, and test your applications across many devices. See the Xcode team show how to set up and configure bots, review unit and performance testing data, and set up custom triggers and integration points."
        session.title = "Continuous Integration with Xcode 6"
        session.eventIdentifier = event.identifier
        session.focuses.append(focus)

        let session2 = Session()

        session2.identifier = "wwdc2014-206"
        session2.number = "206"
        session2.summary = "The modern WebKit framework enables developers to integrate web content into their native app experience with more features and fewer lines of code. Dive into the latest WebKit enhancements including modern Objective-C features such as blocks and explicit object types, advanced bridging between JavaScript and Objective-C, increased JavaScript performance via WebKit's super-fast JIT, and more—all delivered in an API unified for both iOS and OS X."
        session2.title = "Introducing the Modern WebKit API"
        session2.eventIdentifier = event.identifier
        session2.focuses.append(focus)

        let asset = SessionAsset()
        asset.assetType = .hdVideo
        asset.relativeLocalURL = "2014/208_hd_introducing_cloudkit.mov"
        asset.remoteURL = "http://devstreaming.apple.com/videos/wwdc/2014/208xx42tf0hw3vv/208/208_hd_introducing_cloudkit.mov"

        let asset2 = SessionAsset()
        asset2.assetType = .streamingVideo
        asset2.remoteURL = "http://devstreaming.apple.com/videos/wwdc/2014/208xx42tf0hw3vv/208/ref.mov"

        let photoRep = PhotoRepresentation()
        photoRep.remotePath = "4FF1EAAF-7D24-4F20-A182-0AA1FBB4D8DE/512.jpeg"
        photoRep.width = 512

        let photoRep2 = PhotoRepresentation()
        photoRep2.remotePath = "CC9D2377-90B0-4750-8C97-549DEC08C028/1024.jpeg"
        photoRep2.width = 1024

        let instance = SessionInstance()
        instance.session = session
        instance.startTime = Date.distantPast
        instance.endTime = Date.distantFuture

        let annotation = TranscriptAnnotation()
        annotation.timecode = 32.466
        annotation.body = "So the first thing, if you'd help me out"

        let transcript = Transcript()
        transcript.identifier = "2014-206"
        transcript.annotations.append(annotation)

        let favorite = Favorite()
        favorite.createdAt = Date()
        favorite.identifier = UUID().uuidString

        let bookmark = Bookmark()
        bookmark.identifier = UUID().uuidString
        bookmark.createdAt = Date()
        bookmark.modifiedAt = Date()
        bookmark.body = "Hello, world!"
        let str = NSAttributedString(string: "Hello, world!")
        bookmark.attributedBody = NSKeyedArchiver.archivedData(withRootObject: str)
        bookmark.timecode = annotation.timecode
        bookmark.annotation = annotation

        session.transcriptIdentifier = transcript.identifier
        session.transcriptText = transcript.fullText

        session.bookmarks.append(bookmark)
        session.favorites.append(favorite)
        session.assets.append(asset)
        session.assets.append(asset2)

        let relatedSessionResource = RelatedResource()
        relatedSessionResource.identifier = "wwdc2014-206"
        relatedSessionResource.type = RelatedResourceType.session.rawValue

        session.related.append(relatedSessionResource)

        let relatedResource = RelatedResource()
        relatedResource.identifier = "wwdc2014-206"
        relatedResource.type = "WWDCSessionResourceTypeSession"

        return ContentsResponse(
            events: [event],
            rooms: [room],
            tracks: [track],
            resources: [relatedResource],
            instances: [instance],
            sessions: [session, session2])
    }
}
