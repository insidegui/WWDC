import Foundation

extension String: LocalizedError {
    public var errorDescription: String? { self }
}
