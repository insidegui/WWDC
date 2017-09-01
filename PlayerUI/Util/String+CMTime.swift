//
//  String+CMTime.swift
//  PlayerUI
//
//  Created by Guilherme Rambo on 30/04/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Foundation
import AVFoundation

extension String {

    public init?(timestamp: Double) {
        let prefix = timestamp < 0 ? "-" : ""

        let date = Date(timeInterval: TimeInterval(timestamp), since: Date())
        let components = Calendar.current.dateComponents([.hour, .minute, .second], from: Date(), to: date)

        guard let hour = components.hour, let minute = components.minute, let second = components.second else {
            return nil
        }

        let hourString = String(format: "%02d", abs(hour))
        let minuteString = String(format: "%02d", abs(minute))
        let secondString = String(format: "%02d", abs(second))

        var bits = [minuteString, secondString]

        if hour > 0 {
            bits.insert(hourString, at: 0)
        }

        self.init(prefix + bits.joined(separator: ":"))
    }

    public init?(time: CMTime) {
        let secondCount = time.value / Int64(time.timescale)

        self.init(timestamp: Double(secondCount))
    }

}
