//
//  DatabaseTests.swift
//  ConfCoreTests
//
//  Created by Guilherme Rambo on 05/02/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import XCTest
import RealmSwift
@testable import ConfCore

class DatabaseTests: XCTestCase {

    private lazy var realmConfiguration: Realm.Configuration? = {
        guard let desktop = NSSearchPathForDirectoriesInDomains(.desktopDirectory, .userDomainMask, true).first else { return nil }
        let dirPath = desktop + "/ConfCoreStorage/\(Date().timeIntervalSinceReferenceDate)/"

        if !FileManager.default.fileExists(atPath: dirPath) {
            do {
                try FileManager.default.createDirectory(atPath: dirPath, withIntermediateDirectories: true, attributes: nil)
            } catch {
                return nil
            }
        }

        return Realm.Configuration(fileURL: URL(fileURLWithPath: dirPath + "tests.realm"))
    }()

    /// Make sure all objects and relationships are correct
    func testRealmObjectsAndRelationships() {
        guard let config = self.realmConfiguration else {
            XCTFail("Unable to create realm for tests")
            return
        }

        let realm = try! Realm(configuration: config)

        try! realm.write {
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

            let keyword = Keyword()
            keyword.name = "objective c"

            let room = Room()
            room.mapName = "Session-NobHill"
            room.name = "Nob Hill"
            room.floor = "floor2"

            let session = Session()
            session.identifier = "wwdc2014-206"
            session.number = "206"
            session.summary = "The modern WebKit framework enables developers to integrate web content into their native app experience with more features and fewer lines of code. Dive into the latest WebKit enhancements including modern Objective-C features such as blocks and explicit object types, advanced bridging between JavaScript and Objective-C, increased JavaScript performance via WebKit's super-fast JIT, and more—all delivered in an API unified for both iOS and OS X."
            session.title = "Introducing the Modern WebKit API"
            session.focuses.append(focus)

            let asset = SessionAsset()
            asset.assetType = "WWDCSessionAssetTypeHDVideo"
            asset.isDownloaded = true
            asset.relativeLocalURL = "2014/208_hd_introducing_cloudkit.mov"
            asset.remoteURL = "http://devstreaming.apple.com/videos/wwdc/2014/208xx42tf0hw3vv/208/208_hd_introducing_cloudkit.mov"

            let asset2 = SessionAsset()
            asset2.assetType = "WWDCSessionAssetTypeStreamingVideo"
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

            let newsItem = NewsItem()
            newsItem.newsType = 0
            newsItem.identifier = "74C86280-622B-4BC0-B56A-5C270C5B18D1"
            newsItem.title = "Check-In"
            newsItem.body = "Badges will be available to pick up starting Sunday, June 12.\n\nBill Graham Civic Auditorium:\n\nSunday (9 AM – 7 PM)\n\nMonday (7 AM – 7 PM)\n\nMoscone West:\nTuesday – Friday (8 AM – 6 PM)"
            newsItem.visibility = "user.accessLevel == 6"

            let gallery = NewsItem()
            gallery.identifier = "E55831D4-8CC0-4073-8D22-6F8F9DDE8DF4"
            gallery.newsType = 2
            gallery.title = "Connecting at the Get Togethers"
            gallery.body = "13 photos"

            let photo = Photo()
            photo.identifier = "C720F641-6928-4023-9EA4-B7AF5C3206D0"
            photo.aspectRatio = 1.5060

            photo.representations.append(photoRep)
            photo.representations.append(photoRep2)
            gallery.photos.append(photo)

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

            session.bookmarks.append(bookmark)
            session.favorites.append(favorite)
            session.transcript = transcript

            room.instances.append(instance)
            session.assets.append(asset)
            session.assets.append(asset2)
            track.sessions.append(session)
            event.sessions.append(session)

            realm.add(favorite)
            realm.add(bookmark)
            realm.add(annotation)
            realm.add(transcript)
            realm.add(photo)
            realm.add(gallery)
            realm.add(newsItem)
            realm.add(event)
            realm.add(track)
            realm.add(focus)
            realm.add(keyword)
            realm.add(asset)
            realm.add(asset2)
            realm.add(photoRep)
            realm.add(photoRep2)
            realm.add(instance)
            realm.add(room)
            realm.add(session)
        }

        let event = realm.objects(Event.self).first
        XCTAssertNotNil(event)
        XCTAssertEqual(event?.sessions.count, 1)
        XCTAssertEqual(event?.sessions.first?.event.first?.name, event?.name)

        let track = realm.objects(Track.self).first
        XCTAssertNotNil(track)
        XCTAssertEqual(track?.sessions.count, 1)
        XCTAssertEqual(track?.sessions.first?.track.first?.name, track?.name)

        let focus = realm.objects(Focus.self).first
        XCTAssertNotNil(focus)
        XCTAssertEqual(focus?.sessions.count, 1)
        XCTAssertEqual(focus?.sessions.first?.focuses.first?.name, focus?.name)

        let keyword = realm.objects(Keyword.self).first
        XCTAssertNotNil(keyword)
        let room = realm.objects(Room.self).first
        XCTAssertNotNil(room)
        XCTAssertEqual(room?.instances.count, 1)
        XCTAssertEqual(room?.instances.first?.room.first?.name, room?.name)

        let session = realm.objects(Session.self).first
        XCTAssertNotNil(session)
        XCTAssertEqual(session?.assets.count, 2)
        XCTAssertEqual(session?.favorites.count, 1)
        XCTAssertEqual(session?.bookmarks.count, 1)
        XCTAssertEqual(session?.focuses.count, 1)
        XCTAssertEqual(session?.track.count, 1)
        XCTAssertEqual(session?.event.count, 1)
        XCTAssertNotNil(session?.transcript)

        let gallery = realm.object(ofType: NewsItem.self,
                                   forPrimaryKey: "E55831D4-8CC0-4073-8D22-6F8F9DDE8DF4")
        XCTAssertNotNil(gallery)
        XCTAssertEqual(gallery?.photos.count, 1)
        XCTAssertEqual(gallery?.photos.first?.representations.count, 2)
    }
    
}
