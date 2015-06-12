//
//  TranscriptSearchOperation.swift
//  WWDC
//
//  Created by Guilherme Rambo on 05/06/15.
//  Copyright (c) 2015 Guilherme Rambo. All rights reserved.
//

import Cocoa
import ASCIIwwdc

class SearchOperation: NSOperation {

    private let validQualifiers = ["year", "focus", "track", "downloaded", "favorited", "description", "transcript"]
    
    var sessions: [Session]
    var term: String?
    var completionHandler: () -> Void = {}
    
    var result: [Session]! {
        didSet {
            if result != nil && !cancelled {
                completionHandler()
            }
        }
    }
    
    init(sessions: [Session], term: String?, completionHandler: () -> Void) {
        self.sessions = sessions
        self.term = term
        self.completionHandler = completionHandler
    }
    
    override func main() {
        if let term = term {
            if term == "" {
                result = sessions
            } else {
                var qualifiers = term.qualifierSearchParser_parseQualifiers(validQualifiers)
                
                result = sessions.filter { session in
                    if let transcript: String = qualifiers["transcript"] as? String {
                        let result = ASCIIWWDCTranscriptIndexer.sharedIndexer().fullTextSearchFor(transcript, matches: session.uniqueKey)
                        if !result {
                            return false
                        }
                    }
                    
                    if let year: String = qualifiers["year"] as? String {
                        let yearStr = "\(session.year)"
                        let result = (yearStr as NSString).rangeOfString(year, options: .CaseInsensitiveSearch)
                        if result.location + result.length != count(yearStr) {
                            return false
                        }
                    }
                    
                    if let focus: String = qualifiers["focus"] as? String {
                        var fixedFocus: String = focus
                        if focus.lowercaseString == "osx" || focus.lowercaseString == "os x" {
                            fixedFocus = "OS X"
                        } else if focus.lowercaseString == "ios" {
                            fixedFocus = "iOS"
                        }
                        
                        if !contains(session.focus, fixedFocus) {
                            return false
                        }
                    }
                    
                    if let track: String = qualifiers["track"] as? String {
                        if session.track.lowercaseString != track.lowercaseString {
                            return false
                        }
                    }
                    
                    if let description: String = qualifiers["description"] as? String {
                        if let range = session.description.rangeOfString(description, options: .CaseInsensitiveSearch | .DiacriticInsensitiveSearch, range: nil, locale: nil) {
                            // continue...
                        } else {
                            return false
                        }
                    }
                    
                    if let downloaded: String = qualifiers["downloaded"] as? String {
                        if let url = session.hd_url {
                            return (VideoStore.SharedStore().hasVideo(url) == downloaded.boolValue)
                        } else {
                            return false
                        }
                    }
                    
                    if let favorited: String = qualifiers["favorited"] as? String {
                        return session.favorite
                    }
                    
                    if let query: String = qualifiers["_query"] as? String {
                        if query != "" {
                            if let range = session.title.rangeOfString(query, options: .CaseInsensitiveSearch | .DiacriticInsensitiveSearch, range: nil, locale: nil) {
                                //Nothing here...
                            } else {
                                return false
                            }
                        }
                    }
                    
                    return true
                }
            }
        }
    }
    
}
