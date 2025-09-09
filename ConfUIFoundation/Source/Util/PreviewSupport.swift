import SwiftUI

public extension NSApplication {
    @MainActor
    var isPreview: Bool {
#if DEBUG
        return ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
#else
        return false
#endif
    }
}

public extension ProcessInfo {

    /// In debug builds, `true` if the current process is running in a SwiftUI preview.
    /// Always `false` in release builds.
    @objc static let isSwiftUIPreview: Bool = {
#if DEBUG
        return processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
#else
        return false
#endif
    }()

    /// In debug builds, `true` if the current process is running in an interactive SwiftUI preview.
    /// `false` if the SwiftUI preview is not interactive or if running in a release build.
    static var isInteractiveSwiftUIPreview: Bool {
        /// `isSwiftUIPreview` already has the `#if DEBUG` check,
        /// but we don't want the implementation of this method to show up in release builds at all, so replicate that here.
#if DEBUG
        guard isSwiftUIPreview else { return false }

        /// `PreviewHostingWindow` is used for non-interactive previews, but this modifier requires interactive previews.
        /// This might break in the future since it relies on implementation details of SwiftUI previews.
        return !NSApplication.shared.windows.contains(where: { $0.className.contains("PreviewHostingWindow") })
#else
        return false
#endif
    }
}
