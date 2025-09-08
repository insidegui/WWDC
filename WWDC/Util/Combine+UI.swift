//
//  Combine+UI.swift
//  WWDC
//
//  Created by Allen Humphreys on 5/28/23.
//  Copyright © 2023 Guilherme Rambo. All rights reserved.
//

import Combine
import RealmSwift

extension Publisher {
    func `do`(_ closure: @escaping () -> Void) -> some Publisher<Output, Failure> {
        map {
            closure()
            return $0
        }
    }

    func `do`(_ closure: @escaping (Output) -> Void) -> some Publisher<Output, Failure> {
        map {
            closure($0)
            return $0
        }
    }
}

extension Publisher where Failure == Never {
    public func driveUI<Root>(
        _ keyPath: ReferenceWritableKeyPath<Root, Self.Output>,
        on object: Root
    ) -> AnyCancellable {
        receive(on: DispatchQueue.main)
            .assign(to: keyPath, on: object)
    }
}

extension Publisher where Output: Equatable, Failure == Never {
    public func driveUI<Root>(
        _ keyPath: ReferenceWritableKeyPath<Root, Self.Output>,
        on object: Root
    ) -> AnyCancellable {
        removeDuplicates()
            .receive(on: DispatchQueue.main)
            .assign(to: keyPath, on: object)
    }
}

extension Publisher {
    public func compacted<Unwrapped>() -> some Publisher<Unwrapped, Failure> where Output == Unwrapped? {
        compactMap { $0 }
    }

    public func replaceNilAndError<Unwrapped>(with replacement: Unwrapped) -> some Publisher<Unwrapped, Never> where Output == Unwrapped? {
        replaceNil(with: replacement).replaceError(with: replacement)
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

}

extension Publisher {
    func replaceErrorWithEmpty() -> some Publisher<Output, Never> {
        self.catch { _ in
            // TODO: Errors
            Empty<Output, Never>()
        }
    }
}

extension Publisher where Output == Bool {
    func toggled() -> some Publisher<Output, Failure> {
        map { !$0 }
    }
}

extension Publisher {
    /// Assigns values to a property using a weak reference to avoid retain cycles.
    ///
    /// Unlike `assign(to:on:)`, this method captures the object weakly. The returned
    /// `AnyCancellable` is not automatically cancelled when the object is deallocated -
    /// it assumes the object will store and release it.
    ///
    /// **Future:** Could auto-cancel on object deinit using associated objects or a
    /// lifecycle-aware subscriber.
    func weakAssign<Root: AnyObject>(
        to keyPath: ReferenceWritableKeyPath<Root, Output>,
        on object: Root
    ) -> AnyCancellable where Failure == Never {
        sink { [weak object] value in
            object?[keyPath: keyPath] = value
        }
    }

    func weakAssignIfDifferent<Root: AnyObject>(
        to keyPath: ReferenceWritableKeyPath<Root, Output>,
        on object: Root
    ) -> AnyCancellable where Failure == Never, Output: Equatable {
        sink { [weak object] value in
            if object?[keyPath: keyPath] != value {
                object?[keyPath: keyPath] = value
            }
        }
    }
}
