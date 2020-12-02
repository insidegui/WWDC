//
//  Coalescer.swift
//  Transcripts
//
//  Created by Guilherme Rambo on 25/05/20.
//  Copyright © 2020 Guilherme Rambo. All rights reserved.
//

import Foundation

final class Coalescer<T> {

    let delay: TimeInterval

    init(delay: TimeInterval) {
        self.delay = delay
    }

    private let serialQueue = DispatchQueue(label: "Coalescer")

    private var buffer: [T] = []

    private var workItem: DispatchWorkItem?

    func run(for contents: [T], queue: DispatchQueue, callback: @escaping ([T]) -> Void) {
        workItem?.cancel()
        workItem = nil

        serialQueue.sync { [weak self] in
            self?.buffer += contents
        }

        workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }

            let buf = self.serialQueue.sync { return self.buffer }
            callback(buf)

            self.serialQueue.sync { self.buffer.removeAll() }

            self.workItem = nil
        }

        queue.asyncAfter(deadline: .now() + delay, execute: workItem!)
    }

}
