import Foundation

extension MediaDownload {
    static func sortingFunction(lhs: MediaDownload, rhs: MediaDownload) -> Bool {
        switch (lhs.state, rhs.state) {
        case (.paused, .paused):
            break
        case (.paused, _):
            return true
        case (_, .paused):
            return false
        case (.downloading, .downloading):
            break
        case (.downloading, _):
            return false
        case (_, .downloading):
            return true
        default:
            break
        }

        /// Each "section" is sorted by identifier
        return rhs.id < lhs.id
    }
}
