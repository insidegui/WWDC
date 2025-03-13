import Foundation

extension String: @retroactive LocalizedError {
    public var errorDescription: String? { self }
}
