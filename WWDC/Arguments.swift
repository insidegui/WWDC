//
//  Arguments.swift
//  WWDC
//
//  Created by Guilherme Rambo on 13/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Foundation

struct Arguments {

    private static var args: [String] {
        return ProcessInfo.processInfo.arguments
    }

    static var skipMigration: Bool {
        return args.contains("--skip-migration")
    }

    static var useTestVideo: Bool {
        return args.contains("--use-test-video")
    }

    static var showPreferences: Bool {
        return args.contains("--prefs")
    }

    static var disableRemoteEnvironment: Bool {
        return args.contains("--no-remote")
    }

    static var deloreanDate: String? {
        guard let deloreanIndex = args.index(of: "--delorean") else { return nil }

        guard args.count > deloreanIndex + 1 else { return nil }

        return args[deloreanIndex + 1]
    }

}
