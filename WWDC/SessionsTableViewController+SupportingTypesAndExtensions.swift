//
//  SessionsTableViewController+SupportingTypesAndExtensions.swift
//  WWDC
//
//  Created by Allen Humphreys on 6/6/18.
//  Copyright © 2018 Guilherme Rambo. All rights reserved.
//

import ConfCore
import RealmSwift
import RxRealm
import RxSwift
import os.log

/// Conforming to this protocol means the type is capable
/// of uniquely identifying a `Session`
///
/// TODO: Move to ConfCore and make it "official"?
protocol SessionIdentifiable {
    var sessionIdentifier: String { get }
}

struct SessionIdentifier: SessionIdentifiable, Hashable {
    let sessionIdentifier: String

    init(_ string: String) {
        sessionIdentifier = string
    }
}

extension SessionViewModel: SessionIdentifiable {
    var sessionIdentifier: String {
        return identifier
    }
}

protocol SessionsTableViewControllerDelegate: class {

    func sessionTableViewContextMenuActionWatch(viewModels: [SessionViewModel])
    func sessionTableViewContextMenuActionUnWatch(viewModels: [SessionViewModel])
    func sessionTableViewContextMenuActionFavorite(viewModels: [SessionViewModel])
    func sessionTableViewContextMenuActionRemoveFavorite(viewModels: [SessionViewModel])
    func sessionTableViewContextMenuActionDownload(viewModels: [SessionViewModel])
    func sessionTableViewContextMenuActionCancelDownload(viewModels: [SessionViewModel])
    func sessionTableViewContextMenuActionRevealInFinder(viewModels: [SessionViewModel])
}

extension Session {

    var isWatched: Bool {
        if let progress = progresses.first {
            return progress.relativePosition > Constants.watchedVideoRelativePosition
        }

        return false
    }
}

extension Array where Element == SessionRow {

    func index(of session: SessionIdentifiable) -> Int? {
        return firstIndex { row in
            guard case .session(let viewModel) = row.kind else { return false }

            return viewModel.identifier == session.sessionIdentifier
        }
    }

    func firstSessionRowIndex() -> Int? {
        return firstIndex { row in
            if case .session = row.kind {
                return true
            }
            return false
        }
    }

    func forEachSessionViewModel(_ body: (SessionViewModel) throws -> Void) rethrows {
        try forEach {
            if case .session(let viewModel) = $0.kind {
                try body(viewModel)
            }
        }
    }
}

final class FilterResults {

    static var empty: FilterResults {
        return FilterResults(storage: nil, query: nil)
    }

    private let query: NSPredicate?

    private let storage: Storage?

    private(set) var latestSearchResults: Results<Session>?

    private var disposeBag = DisposeBag()
    private let nowPlayingBag = DisposeBag()

    private var observerClosure: ((Results<Session>?) -> Void)?
    private var observerToken: NotificationToken?

    init(storage: Storage?, query: NSPredicate?) {
        self.storage = storage
        self.query = query

        if let coordinator = (NSApplication.shared.delegate as? AppDelegate)?.coordinator {

            coordinator
                .rxPlayerOwnerSessionIdentifier
                .subscribe(onNext: { [weak self] _ in
                    self?.bindResults()
                }).disposed(by: nowPlayingBag)
        }
    }

    func observe(with closure: @escaping (Results<Session>?) -> Void) {
        assert(observerClosure == nil)

        guard query != nil, storage != nil else {
            closure(nil)
            return
        }

        observerClosure = closure

        bindResults()
    }

    private func bindResults() {
        guard let observerClosure = observerClosure else { return }
        guard let storage = storage, let query = query?.orCurrentlyPlayingSession() else { return }

        disposeBag = DisposeBag()

        do {
            let realm = try Realm(configuration: storage.realmConfig)

            let objects = realm.objects(Session.self).filter(query)

            Observable
                .shallowCollection(from: objects, synchronousStart: true)
                .subscribe(onNext: { [weak self] in
                    self?.latestSearchResults = $0
                    observerClosure($0)
                }).disposed(by: disposeBag)
        } catch {
            observerClosure(nil)
            os_log("Failed to initialize Realm for searching: %{public}@",
                   log: .default,
                   type: .error,
                   String(describing: error))
        }
    }
}

fileprivate extension NSPredicate {

    func orCurrentlyPlayingSession() -> NSPredicate {

        guard let playingSession = (NSApplication.shared.delegate as? AppDelegate)?.coordinator?.playerOwnerSessionIdentifier else {
            return self
        }

        return NSCompoundPredicate(orPredicateWithSubpredicates: [self, NSPredicate(format: "identifier == %@", playingSession)])
    }
}

public extension ObservableType where Element: NotificationEmitter {

    /**
     Returns an `Observable<E>` that emits each time elements are added or removed from the collection.
     The observable emits an initial value upon subscription. Similar to `collection(from:synchronousStart)` but
     is limited to emitting when elements are added or removed from the collection. Useful for less brute-forcey UI
     updates.

     - parameter from: A Realm collection of type `E`: either `Results`, `List`, `LinkingObjects` or `AnyRealmCollection`.
     - parameter synchronousStart: whether the resulting `Observable` should emit its first element synchronously (e.g. better for UI bindings)

     - returns: `Observable<E>`, e.g. when called on `Results<Model>` it will return `Observable<Results<Model>>`, on a `List<User>` it will return `Observable<List<User>>`, etc.
     */
    static func shallowCollection(from collection: Element, synchronousStart: Bool = true)
        -> Observable<Element> {

            return Observable.create { observer in
                if synchronousStart {
                    observer.onNext(collection)
                }

                let token = collection.observe(on: nil) { changeset in

                    var value: Element?

                    switch changeset {
                    case .initial(let latestValue):
                        guard !synchronousStart else { return }
                        value = latestValue

                    case .update(let latestValue, let deletions, let insertions, _) where !deletions.isEmpty || !insertions.isEmpty:
                        value = latestValue

                    case .error(let error):
                        observer.onError(error)
                        return
                    default: ()
                    }

                    value.map(observer.onNext)
                }

                return Disposables.create {
                    token.invalidate()
                }
            }
    }
}
