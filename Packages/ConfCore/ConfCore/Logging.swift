//
//  Logging.swift
//  
//
//  Created by Allen Humphreys on 6/5/23.
//

import OSLog

public typealias OSLogger = os.Logger

public struct LoggingConfig {
    public let subsystem: String
    public let category: String
}

public protocol Logging {
    static var log: OSLogger { get }
    var log: OSLogger { get }
    static func defaultLoggerConfig() -> LoggingConfig
    static func makeLogger(config: LoggingConfig) -> OSLogger
}

public extension Logging {
    static func defaultLoggerConfig() -> LoggingConfig {
        let fullyQualifiedTypeName = String(reflecting: Self.self)
        let fullyQualifiedTypeNameComponents = fullyQualifiedTypeName.split(separator: ".", maxSplits: 1)
        let subsystem = fullyQualifiedTypeNameComponents[0]
        let category = fullyQualifiedTypeNameComponents[1]
        return LoggingConfig(subsystem: String(subsystem), category: String(category))
    }
    @inline(__always)
    static func makeLogger(config: LoggingConfig = defaultLoggerConfig()) -> OSLogger {
        makeLogger(subsystem: config.subsystem, category: config.category)
    }
    @inline(__always)
    static func makeLogger(subsystem: String, category: String = String(describing: Self.self)) -> OSLogger {
        ConfCore.makeLogger(subsystem: subsystem, category: category)
    }

    /// Convenience forwarding the static log var to the instance just to make things simpler and easier. Types conforming to Logging only
    /// need to create the static var
    @inline(__always)
    var log: OSLogger { Self.log }

}

/// Mostly for identifying places that log outside of using the Logging protocol. To help with future refactors.
@inline(__always)
public func makeLogger(subsystem: String, category: String) -> OSLogger {
    OSLogger(subsystem: subsystem, category: category)
}
