//
//  FeaturedContent.swift
//  ConfCore
//
//  Created by Guilherme Rambo on 26/05/18.
//  Copyright © 2018 Guilherme Rambo. All rights reserved.
//

import Foundation
import RealmSwift

/// Specifies an author for a curated playlist
public class FeaturedContent: Object {

    /// The session id for the relevant session
    @objc public dynamic var sessionId: String = ""

    /// The session this content represents
    @objc public dynamic var session: Session?

    /// RTF data for the essay associated with the content
    @objc public dynamic var essay: Data?

    /// A list of bookmarks
    public let bookmarks = List<Bookmark>()

}
