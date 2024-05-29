import Foundation

/// Can be used to log things in previews and whatnot, only useful in debug builds.
@inlinable
public func UILog(_ value: @autoclosure () -> Any) {
    #if DEBUG
    // swiftlint:disable:next os_log_over_all
    print("💎 \(String(describing: value()))")
    #endif
}
