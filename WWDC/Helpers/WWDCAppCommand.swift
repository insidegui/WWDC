import Foundation

enum WWDCAppCommand: Codable {
    case favorite(_ videoId: String)
    case unfavorite(_ videoId: String)
    case watch(_ videoId: String)
    case unwatch(_ videoId: String)
    case download(_ videoId: String)
    case cancelDownload(_ videoId: String)
    case revealVideo(_ videoId: String)
    case filter(_ state: WWDCFiltersState)
    case launchPreferences
}

extension WWDCAppCommand {
    
    /// `true` if the command can change user content.
    var modifiesUserContent: Bool {
        switch self {
        case .favorite, .unfavorite, .watch, .unwatch, .download, .cancelDownload:
            return true
        case .launchPreferences, .revealVideo, .filter:
            return false
        }
    }
    
    /// If `true`, then the app should become visible when it receives this command.
    var isForeground: Bool {
        switch self {
        case .revealVideo, .launchPreferences, .filter:
            return true
        default:
            return false
        }
    }
    
}

// MARK: - URL scheme

private enum WWDCAppCommandVerb: String {
    case favorite
    case unfavorite
    case watch
    case unwatch
    case download
    case cancelDownload
    case revealVideo
    case launchPreferences
    case filter
}

private enum WWDCAppCommandParameter: String {
    case id
    case filter
}

extension WWDCAppCommand {
    static let urlScheme = "x-wwdc-command"
    
    private func generateURL(with verb: WWDCAppCommandVerb, parameters: [WWDCAppCommandParameter: String]) -> URL? {
        guard var components = URLComponents(string: "\(Self.urlScheme)://") else { return nil }
        components.host = verb.rawValue
        components.queryItems = parameters.map { URLQueryItem(name: $0.key.rawValue, value: $0.value) }
        return components.url
    }
    
    var url: URL? {
        switch self {
        case .favorite(let videoId):
            return generateURL(with: .favorite, parameters: [.id: videoId])
        case .unfavorite(let videoId):
            return generateURL(with: .unfavorite, parameters: [.id: videoId])
        case .watch(let videoId):
            return generateURL(with: .watch, parameters: [.id: videoId])
        case .unwatch(let videoId):
            return generateURL(with: .unwatch, parameters: [.id: videoId])
        case .download(let videoId):
            return generateURL(with: .download, parameters: [.id: videoId])
        case .cancelDownload(let videoId):
            return generateURL(with: .cancelDownload, parameters: [.id: videoId])
        case .revealVideo(let videoId):
            return generateURL(with: .revealVideo, parameters: [.id: videoId])
        case .launchPreferences:
            return generateURL(with: .launchPreferences, parameters: [:])
        case .filter(let state):
            guard let encoded = state.base64Encoded else { return nil }
            return generateURL(with: .filter, parameters: [.filter: encoded])
        }
    }
    
    // swiftlint:disable:next cyclomatic_complexity
    init?(from url: URL) {
        guard url.scheme == Self.urlScheme else { return nil }
        
        guard let host = url.host else { return nil }
        
        guard let verb = WWDCAppCommandVerb(rawValue: host) else { return nil }
        
        switch verb {
        case .favorite:
            guard let id = url.queryItemValue(for: .id) else { return nil }
            self = .favorite(id)
        case .unfavorite:
            guard let id = url.queryItemValue(for: .id) else { return nil }
            self = .unfavorite(id)
        case .watch:
            guard let id = url.queryItemValue(for: .id) else { return nil }
            self = .watch(id)
        case .unwatch:
            guard let id = url.queryItemValue(for: .id) else { return nil }
            self = .unwatch(id)
        case .download:
            guard let id = url.queryItemValue(for: .id) else { return nil }
            self = .download(id)
        case .cancelDownload:
            guard let id = url.queryItemValue(for: .id) else { return nil }
            self = .cancelDownload(id)
        case .revealVideo:
            guard let id = url.queryItemValue(for: .id) else { return nil }
            self = .revealVideo(id)
        case .launchPreferences:
            self = .launchPreferences
        case .filter:
            guard let encoded = url.queryItemValue(for: .filter) else { return nil }
            guard let state = WWDCFiltersState(base64Encoded: encoded) else { return nil }
            self = .filter(state)
        }
    }
}

fileprivate extension URL {
    func queryItemValue(for parameter: WWDCAppCommandParameter) -> String? {
        guard let components = URLComponents(url: self, resolvingAgainstBaseURL: false) else { return nil }
        return components.queryItems?.first(where: { $0.name == parameter.rawValue })?.value
    }
}
