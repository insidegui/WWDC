import Foundation

public let UILogDisabled = UserDefaults.standard.bool(forKey: "WWDCDisableUILog")

/// Can be used to log things in previews and whatnot, only useful in debug builds.
@inlinable
public func UILog(_ value: @autoclosure () -> Any) {
    #if DEBUG
    guard !UILogDisabled else { return }
    // swiftlint:disable:next os_log_over_all
    print("💎 \(String(describing: value()))")
    #endif
}
