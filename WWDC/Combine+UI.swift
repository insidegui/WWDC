//
//  Combine+UI.swift
//  WWDC
//
//  Created by Allen Humphreys on 5/28/23.
//  Copyright © 2023 Guilherme Rambo. All rights reserved.
//

import Combine
import RealmSwift

extension Publisher where Failure == Never {
    func assign<Root: AnyObject>(
        to keyPath: ReferenceWritableKeyPath<Root, Output>,
        onWeak object: Root
    ) -> AnyCancellable {
        sink { [weak object] value in
            object?[keyPath: keyPath] = value
        }
    }

    func assignDebug<Root: AnyObject>(
        to keyPath: ReferenceWritableKeyPath<Root, Output>,
        onWeak object: Root
    ) -> AnyCancellable {
        sink { [weak object] value in
            Swift.print("\(value)")
            object?[keyPath: keyPath] = value
        }
    }
}

extension Publisher {
    public func compacted<Unwrapped>() -> some Publisher<Unwrapped, Failure> where Output == Unwrapped? {
        compactMap { $0 }
    }

    public func driveUI<Root>(
        _ keyPath: ReferenceWritableKeyPath<Root, Self.Output>,
        on object: Root,
        `default`: Output
    ) -> AnyCancellable {
        replaceError(with: `default`)
            .receive(on: DispatchQueue.main)
            .assign(to: keyPath, on: object)
    }
}

extension Publisher where Output: Equatable, Failure: Error {
    public func driveUI(closure: @escaping (Output) -> Void) -> AnyCancellable {
        removeDuplicates()
            .replaceErrorWithEmpty()
            .receive(on: DispatchQueue.main)
            .sink(receiveValue: closure)
    }
}

extension Publisher where Output: Equatable {
    public func driveUI(`default`: Output, closure: @escaping (Output) -> Void) -> AnyCancellable {
        removeDuplicates()
            .replaceError(with: `default`)
            .receive(on: DispatchQueue.main)
            .sink(receiveValue: closure)
    }

//    public func assign<Root>(to keyPath: ReferenceWritableKeyPath<Root, Self.Output>, on object: Root) -> AnyCancellable
    public func driveUI<Root>(
        _ keyPath: ReferenceWritableKeyPath<Root, Self.Output>,
        on object: Root,
        `default`: Output
    ) -> AnyCancellable {
        removeDuplicates()
            .replaceError(with: `default`)
            .receive(on: DispatchQueue.main)
            .assign(to: keyPath, on: object)
    }
}

public extension RealmCollection where Self: RealmSubscribable {
    /// Similar to `changsetPublisher` but only emits a new value when the collection has additions or removals and ignores all upstream
    /// values caused by objects being modified
    var collectionChangedPublisher: some Publisher<Self, Error> {
        changesetPublisher
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
    }
}

extension Publisher {
    func replaceErrorWithEmpty() -> some Publisher<Output, Never> {
        self.catch { _ in
            // TODO: Errors
            Empty<Output, Never>()
        }
    }
}
