import Foundation

extension Bundle {
    func backgroundURLSessionIdentifier(suffix: String) -> String {
        let prefix = bundleIdentifier ?? bundleURL.lastPathComponent
        return "\(prefix).\(suffix)"
    }
}
