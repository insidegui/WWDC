//
//  WWDCSearchClient.swift
//  SearchFoundation
//
//  Created by Guilherme Rambo on 21/02/20.
//  Copyright © 2020 Guilherme Rambo. All rights reserved.
//

import Foundation
import os.log

public final class WWDCSearchClient: NSObject, SearchServiceInterface {

    private let log = OSLog(subsystem: "codes.rambo.WWDCSearchClient", category: String(describing: WWDCSearchClient.self))

    private lazy var connection: NSXPCConnection = {
        let c = NSXPCConnection(machServiceName: "codes.rambo.WWDCSearchAgent", options: [])

        c.remoteObjectInterface = getSearchServiceXPCInterface()
        
        c.invalidationHandler = { [weak self] in
            guard let self = self else { return }

            os_log("Connection to search agent invalidated", log: self.log, type: .debug)
        }

        return c
    }()

    public override init() {
        super.init()

        connection.resume()
    }

    private var agent: SearchServiceInterface? {
        connection.remoteObjectProxy as? SearchServiceInterface
    }

    public func search(using term: String, with reply: @escaping ([WWDCSearchResult]) -> Void) {
        agent?.search(using: term, with: reply)
    }

}
