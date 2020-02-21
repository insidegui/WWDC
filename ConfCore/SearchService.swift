//
//  SearchService.swift
//  ConfCore
//
//  Created by Guilherme Rambo on 21/02/20.
//  Copyright © 2020 Guilherme Rambo. All rights reserved.
//

import Cocoa
import RealmSwift
import WWDCSearchFoundation
import os.log

public final class SearchService: NSObject, SearchServiceInterface {

    private lazy var listener: NSXPCListener = {
        let l = NSXPCListener(machServiceName: Self.machServiceName)

        l.delegate = self

        return l
    }()

    public static let machServiceName = "codes.rambo.WWDCSearchAgent"

    public static let subsystemName = "codes.rambo.WWDCSearchService"

    private let log = OSLog(subsystem: SearchService.subsystemName, category: String(describing: SearchService.self))

    private let storage: Storage

    public init(storage: Storage) {
        self.storage = storage

        super.init()
    }

    public func listen() {
        listener.resume()

        os_log("Search service listening", log: self.log, type: .debug)
    }

    private func predicate(for term: String) -> NSPredicate {
        let modelKeys = ["title"]

        var subpredicates = modelKeys.map { key -> NSPredicate in
            return NSPredicate(format: "\(key) CONTAINS[cd] %@", term)
        }

        let keywords = NSPredicate(format: "SUBQUERY(instances, $instances, ANY $instances.keywords.name CONTAINS[cd] %@).@count > 0", term)
        subpredicates.append(keywords)

        let bookmarks = NSPredicate(format: "ANY bookmarks.body CONTAINS[cd] %@", term)
        subpredicates.append(bookmarks)

        let transcripts = NSPredicate(format: "transcriptText CONTAINS[cd] %@", term)
        subpredicates.append(transcripts)

        return NSCompoundPredicate(orPredicateWithSubpredicates: subpredicates)
    }

    public func search(using term: String, with reply: @escaping ([WWDCSearchResult]) -> Void) {
        guard !term.isEmpty else {
            reply([])
            return
        }

        do {
            os_log("Performing search with %@", log: self.log, type: .debug, term)

            let realm = try Realm(configuration: storage.realmConfig)

            let filter = predicate(for: term)
            let results = realm.objects(Session.self).filter(filter)

            reply(results.map(WWDCSearchResult.init))
        } catch {
            os_log("Unable to perform search due to error: %{public}@", log: self.log, type: .error, String(describing: error))
        }
    }

}

extension SearchService: NSXPCListenerDelegate {
    public func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        newConnection.exportedInterface = getSearchServiceXPCInterface()
        newConnection.exportedObject = self
        newConnection.resume()

        os_log("Accepting connection from pid %d", log: self.log, type: .default, String(describing: newConnection.processIdentifier))

        return true
    }
}

fileprivate extension WWDCSearchResult {

    convenience init(session: Session) {
        self.init(
            identifier: session.identifier,
            year: session.event[0].year,
            session: Int(session.number) ?? -1,
            summary: session.title,
            deepLink: "wwdcio://session?id=\(session.identifier)"
        )
    }

}
