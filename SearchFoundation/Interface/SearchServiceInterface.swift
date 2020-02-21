//
//  SearchServiceInterface.swift
//  SearchFoundation
//
//  Created by Guilherme Rambo on 21/02/20.
//  Copyright © 2020 Guilherme Rambo. All rights reserved.
//

import Foundation

@objc public protocol SearchServiceInterface: NSObjectProtocol {
    func search(using term: String, with reply: @escaping ([WWDCSearchResult]) -> Void)
}

public func getSearchServiceXPCInterface() -> NSXPCInterface {
    let iface = NSXPCInterface(with: SearchServiceInterface.self)

    // swiftlint:disable:next force_cast
    let replyClasses = NSSet(objects: NSArray.self, WWDCSearchResult.self) as! Set<AnyHashable>
    iface.setClasses(replyClasses, for: #selector(SearchServiceInterface.search(using:with:)), argumentIndex: 0, ofReply: true)

    return iface
}
