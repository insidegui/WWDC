//
//  Created by Allen Humphreys on 7/3/23.
//

import Combine
import RealmSwift

/// This is required to preserve the `subscribe(on:)` capabilities of `changesetPublisher` while filtering out
/// elements that don't contain insertions or removals
public struct ShallowCollectionChangsetPublisher<Collection: RealmCollection>: Publisher {
    public typealias Output = Collection
    /// This publisher reports error via the `.error` case of RealmCollectionChange.
    public typealias Failure = Error

    let upstream: RealmPublishers.CollectionChangeset<Collection>

    init(collectionChangesetPublisher: RealmPublishers.CollectionChangeset<Collection>) {
        self.upstream = collectionChangesetPublisher
    }

    public func receive<S>(subscriber: S) where S: Subscriber, Collection == S.Input, S.Failure == Error {
        upstream
            .tryCompactMap { changeset in
                switch changeset {
                case .initial(let latestValue):
                    return latestValue
                case .update(let latestValue, let deletions, let insertions, _) where !deletions.isEmpty || !insertions.isEmpty:
                    return latestValue
                case .update:
                    return nil
                case .error(let error):
                    throw error
                }
            }
            .receive(subscriber: subscriber)
    }

    public func subscribe<S: Scheduler>(on scheduler: S) -> some Publisher<Collection, Error> {
        ShallowCollectionChangsetPublisher(collectionChangesetPublisher: upstream.subscribe(on: scheduler))
    }
}

public extension RealmCollection where Self: RealmSubscribable {
    /// Similar to `changesetPublisher` but only emits a new value when the collection has additions or removals and ignores all upstream
    /// values caused by objects being modified
    var changesetPublisherShallow: ShallowCollectionChangsetPublisher<Self> {
        ShallowCollectionChangsetPublisher(collectionChangesetPublisher: changesetPublisher)
    }

    /// Similar to `changesetPublisher(keyPaths:)` but only emits a new value when the collection has additions or removals and ignores all upstream
    /// values caused by objects being modified
    func changesetPublisherShallow(keyPaths: [String]) -> ShallowCollectionChangsetPublisher<Self> {
        ShallowCollectionChangsetPublisher(collectionChangesetPublisher: changesetPublisher(keyPaths: keyPaths))
    }
}
