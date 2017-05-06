//
//  SessionViewModel.swift
//  WWDC
//
//  Created by Guilherme Rambo on 22/04/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Foundation
import ConfCore
import IGListKit

final class SessionViewModel: NSObject {
    
    let identifier: String
    let title: String
    let subtitle: String
    let trackName: String
    let summary: String
    let context: String
    let footer: String
    let imageUrl: URL?
    let color: NSColor
    let webUrl: URL?
    
    init?(session: Session) {
        guard let event = session.event.first else { return nil }
        guard let track = session.track.first else { return nil }
        
        self.trackName = track.name
        
        let year = Calendar.current.component(.year, from: event.startDate)
        
        let imageAsset = session.asset(of: .image)
        
        if let thumbnail = imageAsset?.remoteURL, let thumbnailUrl = URL(string: thumbnail) {
            self.imageUrl = thumbnailUrl
        } else {
            self.imageUrl = nil
        }
        
        let focusesArray = session.focuses.toArray()
        
        let focuses = SessionViewModel.focusesDescription(from: focusesArray, collapse: true)
        let allFocuses = SessionViewModel.focusesDescription(from: focusesArray, collapse: false)
        
        var footer = "WWDC \(year) · Session \(session.number)"
        var context = "\(track.name)"
        
        if focusesArray.count > 0 {
            footer += " · \(allFocuses)"
            context = "\(focuses) - " + context
        }
        
        self.identifier = session.identifier
        self.title = session.title
        self.subtitle = "WWDC \(year) - Session \(session.number)"
        self.context = context
        self.color = NSColor.fromHexString(hexString: track.lightColor)
        self.summary = session.summary
        self.footer = footer
        
        if let url = session.asset(of: .webpage)?.remoteURL {
            self.webUrl = URL(string: url)
        } else {
            self.webUrl = nil
        }
        
        super.init()
    }
    
    init(title: String) {
        self.identifier = title
        self.title = title
        self.trackName = ""
        self.subtitle = ""
        self.summary = ""
        self.context = ""
        self.footer = ""
        self.color = .clear
        self.webUrl = nil
        self.imageUrl = nil
        
        super.init()
    }
    
    static func focusesDescription(from focuses: [Focus], collapse: Bool) -> String {
        var result: String
        
        if focuses.count == 4 && collapse {
            result = "All Platforms"
        } else {
            let separator = ", "
            
            result = focuses.reduce("") { partial, focus in
                if partial.isEmpty {
                    return focus.name + separator
                } else {
                    return partial + focus.name + separator
                }
            }
            
            if let lastCommaRange = result.range(of: separator, options: .backwards, range: nil, locale: nil) {
                result = result.replacingCharacters(in: lastCommaRange, with: "")
            }
        }
        
        return result
    }
    
}

extension SessionViewModel: IGListDiffable {
    
    func diffIdentifier() -> NSObjectProtocol {
        return identifier as NSObjectProtocol
    }
    
    func isEqual(toDiffableObject object: IGListDiffable?) -> Bool {
        guard let other = object as? SessionViewModel else { return false }
        
        return self.identifier == other.identifier &&
                self.title == other.title &&
                self.subtitle == other.subtitle &&
                self.context == other.context &&
                self.imageUrl == other.imageUrl &&
                self.color == other.color
    }
    
}

extension SessionViewModel: UserActivityRepresentable { }
