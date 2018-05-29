//
//  AppCoordinator+Bookmarks.swift
//  WWDC
//
//  Created by Guilherme Rambo on 20/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
import AVFoundation
import PlayerUI
import RxSwift
import RxCocoa
import RealmSwift
import RxRealm
import ConfCore

extension AppCoordinator: PUITimelineDelegate, VideoPlayerViewControllerDelegate {

    func createBookmark(at timecode: Double, with snapshot: NSImage?) {
        guard let session = currentPlayerController?.sessionViewModel.session else { return }

        storage.modify(session) { bgSession in
            let bookmark = Bookmark()
            bookmark.timecode = timecode
            bookmark.snapshot = snapshot?.compressedJPEGRepresentation ?? Data()

            bgSession.bookmarks.append(bookmark)
        }

        // TODO: begin editing new bookmark
    }

    func createFavorite() {
        guard let session = currentPlayerController?.sessionViewModel.session else { return }

        storage.createFavorite(for: session)
    }

    func viewControllerForTimelineAnnotation(_ annotation: PUITimelineAnnotation) -> NSViewController? {
        guard let bookmark = annotation as? Bookmark else { return nil }

        return BookmarkViewController(bookmark: bookmark, storage: storage)
    }

    func timelineDidHighlightAnnotation(_ annotation: PUITimelineAnnotation?) {

    }

    func timelineDidSelectAnnotation(_ annotation: PUITimelineAnnotation?) {
        guard let annotation = annotation else { return }

        currentPlayerController?.playerView.seek(to: annotation)
    }

    func timelineCanDeleteAnnotation(_ annotation: PUITimelineAnnotation) -> Bool {
        return true
    }

    func timelineCanMoveAnnotation(_ annotation: PUITimelineAnnotation) -> Bool {
        return true
    }

    func timelineDidMoveAnnotation(_ annotation: PUITimelineAnnotation, to timestamp: Double) {
        storage.moveBookmark(with: annotation.identifier, to: timestamp)
    }

    func timelineDidDeleteAnnotation(_ annotation: PUITimelineAnnotation) {
        storage.softDeleteBookmark(with: annotation.identifier)
    }

}

extension Bookmark: PUITimelineAnnotation {

    public var isEmpty: Bool {
        return body.isEmpty
    }

    public var timestamp: Double {
        return timecode
    }

    public var isValid: Bool {
        return !isInvalidated && !isDeleted
    }

}
