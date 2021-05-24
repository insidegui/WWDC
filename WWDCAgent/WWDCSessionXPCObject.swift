//
//  WWDCSessionXPCObject.swift
//  WWDCAgent
//
//  Created by Guilherme Rambo on 24/05/21.
//  Copyright © 2021 Guilherme Rambo. All rights reserved.
//

import Cocoa

#if AGENT
import ConfCore
#endif

@objc(WWDCSessionXPCObject) @objcMembers class WWDCSessionXPCObject: NSObject, NSSecureCoding, Identifiable {
    
    let id: String
    let title: String
    let summary: String

    #if AGENT
    init(from session: Session) {
        self.id = session.identifier
        self.title = session.title
        self.summary = session.summary
    }
    #endif
    
    static var supportsSecureCoding: Bool { true }
    
    func encode(with coder: NSCoder) {
        coder.encode(id, forKey: "id")
        coder.encode(title, forKey: "title")
        coder.encode(summary, forKey: "summary")
    }
    
    required init?(coder: NSCoder) {
        guard let id = coder.decodeObject(of: NSString.self, forKey: "id") as String? else { return nil }
        guard let title = coder.decodeObject(of: NSString.self, forKey: "title") as String? else { return nil }
        guard let summary = coder.decodeObject(of: NSString.self, forKey: "summary") as String? else { return nil }
        
        self.id = id
        self.title = title
        self.summary = summary
    }

}
