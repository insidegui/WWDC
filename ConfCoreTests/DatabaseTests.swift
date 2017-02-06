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
            track.displayOrder = 2
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
            room.displayOrder = 4
            room.mapName = "Session-NobHill"
            room.name = "Nob Hill"
            room.floor = 2
            
            let session = Session()
            session.sessionType = 0
            session.identifier = "wwdc2014-206"
            session.number = "206"
            session.summary = "The modern WebKit framework enables developers to integrate web content into their native app experience with more features and fewer lines of code. Dive into the latest WebKit enhancements including modern Objective-C features such as blocks and explicit object types, advanced bridging between JavaScript and Objective-C, increased JavaScript performance via WebKit's super-fast JIT, and more—all delivered in an API unified for both iOS and OS X."
            session.title = "Introducing the Modern WebKit API"
            
            let asset = SessionAsset()
            asset.assetType = "WWDCSessionAssetTypeHDVideo"
            asset.isDownloaded = true
            asset.relativeLocalURL = "2014/208_hd_introducing_cloudkit.mov"
            asset.remoteURL = "http://devstreaming.apple.com/videos/wwdc/2014/208xx42tf0hw3vv/208/208_hd_introducing_cloudkit.mov"

            let asset2 = SessionAsset()
            asset2.assetType = "WWDCSessionAssetTypeStreamingVideo"
            asset2.remoteURL = "http://devstreaming.apple.com/videos/wwdc/2014/208xx42tf0hw3vv/208/ref.mov"
            
            let photoRep = PhotoRepresentation()
            photoRep.remoteURL = "https://test.com/test.jpg"
            photoRep.width = 512

            let photoRep2 = PhotoRepresentation()
            photoRep2.remoteURL = "https://test.com/test1024.jpg"
            photoRep2.width = 1024
            
            let instance = SessionInstance()
            instance.startTime = Date.distantPast
            instance.endTime = Date.distantFuture
            instance.liveStreamEndTime = Date.distantFuture
            
            instance.liveStreamPhotoRep = photoRep
            instance.liveStreamAsset = asset2
            
            let newsItem = NewsItem()
            newsItem.newsType = 0
            newsItem.identifier = "74C86280-622B-4BC0-B56A-5C270C5B18D1"
            newsItem.title = "Check-In"
            newsItem.body = "Badges will be available to pick up starting Sunday, June 12.\n\nBill Graham Civic Auditorium:\n\nSunday (9 AM – 7 PM)\n\nMonday (7 AM – 7 PM)\n\nMoscone West:\nTuesday – Friday (8 AM – 6 PM)"
            newsItem.visibility = "user.accessLevel == 6"
            
            let gallery = NewsItem()
            newsItem.newsType = 2
            newsItem.title = "Connecting at the Get Togethers"
            newsItem.body = "13 photos"
            
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
            session.keywords.append(keyword)
            session.instances.append(instance)
            track.sessions.append(session)
            event.sessions.append(session)
            focus.sessions.append(session)
         
            realm.add(favorite)
            realm.add(bookmark)
            realm.add(annotation)
            realm.add(transcript)
            realm.add(photo)
            realm.add(gallery)
            realm.add(newsItem)
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
        
        // TODO: fetch the models created and verify that all relationships are correctly set
    }
    
}
