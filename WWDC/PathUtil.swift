//
//  PathUtil.swift
//  WWDC
//
//  Created by Guilherme Rambo on 22/04/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa

final class PathUtil {

    /// The WWDCUseDebugStorage flag can be used to force debug builds to use
    /// a separate storage from release builds
    static var shouldUseDebugStorage: Bool {
        return UserDefaults.standard.bool(forKey: "WWDCUseDebugStorage")
    }

    enum AppSupportCreationError: Error {
        case fileExists

        var localizedDescription: String {
            switch self {
            case .fileExists:
                return "A file exists with the same name as the app support directory"
            }
        }
    }

    /// The application support directory path for the app, use this if you can assume it to be already created
    static var appSupportPathAssumingExisting: String {
        guard let identifier = Bundle.main.bundleIdentifier else {
            fatalError("Bundle identifier is nil, this should never happen")
        }

        let dir = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true).first!

        #if DEBUG
            var path = dir + "/\(identifier)"

            if shouldUseDebugStorage {
                path += ".debug"
            }
        #else
            let path = dir + "/\(identifier)"
        #endif

        return path
    }

    /// Creates and returns the app support path
    ///
    /// - Returns: The path to the app support directory
    /// - Throws: If the directory doesn't exist and can't be created
    static func appSupportPathCreatingIfNeeded() throws -> String {
        let path = appSupportPathAssumingExisting

        var isDirectory: ObjCBool = false

        if !FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) {
            try FileManager.default.createDirectory(atPath: path,
                                                    withIntermediateDirectories: false,
                                                    attributes: nil)
        } else {
            guard isDirectory.boolValue else {
                throw AppSupportCreationError.fileExists
            }
        }

        return path
    }

}
