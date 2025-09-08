// source: https://github.com/CombineCommunity/CombineExt

// Copyright (c) 2020 Combine Community, and/or Shai Mishali
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

import Combine

@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public extension Publisher {
    /// Projects `self` and a `Collection` of `Publisher`s onto a type-erased publisher that chains `combineLatest` calls on
    /// the inner publishers. This is a variadic overload on Combine’s variants that top out at arity three.
    ///
    /// - parameter others: A `Collection`-worth of other publishers with matching output and failure types to combine with.
    ///
    /// - returns: A type-erased publisher with value events from `self` and each of the inner publishers `combineLatest`’d
    /// together in an array.
    func combineLatest<Others: Collection>(with others: Others)
    -> AnyPublisher<[Output], Failure>
    where Others.Element: Publisher, Others.Element.Output == Output, Others.Element.Failure == Failure {
        ([self.eraseToAnyPublisher()] + others.map { $0.eraseToAnyPublisher() }).combineLatest()
    }

    /// Projects `self` and a `Collection` of `Publisher`s onto a type-erased publisher that chains `combineLatest` calls on
    /// the inner publishers. This is a variadic overload on Combine’s variants that top out at arity three.
    ///
    /// - parameter others: A `Collection`-worth of other publishers with matching output and failure types to combine with.
    ///
    /// - returns: A type-erased publisher with value events from `self` and each of the inner publishers `combineLatest`’d
    /// together in an array.
    func combineLatest<Other: Publisher>(with others: Other...)
    -> AnyPublisher<[Output], Failure>
    where Other.Output == Output, Other.Failure == Failure {
        combineLatest(with: others)
    }
}

@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public extension Collection where Element: Publisher {
    /// Projects a `Collection` of `Publisher`s onto a type-erased publisher that chains `combineLatest` calls on
    /// the inner publishers. This is a variadic overload on Combine’s variants that top out at arity three.
    ///
    /// - returns: A type-erased publisher with value events from each of the inner publishers `combineLatest`’d
    /// together in an array.
    func combineLatest() -> AnyPublisher<[Element.Output], Element.Failure> {
        var wrapped = map { $0.map { [$0] }.eraseToAnyPublisher() }
        while wrapped.count > 1 {
            wrapped = makeCombinedQuads(input: wrapped)
        }
        return wrapped.first?.eraseToAnyPublisher() ?? Empty().eraseToAnyPublisher()
    }
}

// MARK: - Private helpers
@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
/// CombineLatest an array of input publishers in four-somes.
///
/// - parameter input: An array of publishers
private func makeCombinedQuads<Output, Failure: Swift.Error>(
    input: [AnyPublisher<[Output], Failure>]
) -> [AnyPublisher<[Output], Failure>] {
    // Iterate over the array of input publishers in steps of four
    sequence(
        state: input.makeIterator(),
        next: { it in it.next().map { ($0, it.next(), it.next(), it.next()) } }
    )
    .map { quad in
        // Only one publisher
        guard let second = quad.1 else { return quad.0 }

        // Two publishers
        guard let third = quad.2 else {
            return quad.0
                .combineLatest(second)
                .map { $0.0 + $0.1 }
                .eraseToAnyPublisher()
        }

        // Three publishers
        guard let fourth = quad.3 else {
            return quad.0
                .combineLatest(second, third)
                .map { $0.0 + $0.1 + $0.2 }
                .eraseToAnyPublisher()
        }

        // Four publishers
        return quad.0
            .combineLatest(second, third, fourth)
            .map { $0.0 + $0.1 + $0.2 + $0.3 }
            .eraseToAnyPublisher()
    }
}
