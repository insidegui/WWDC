//
//  WWDCAppCommand.swift
//  WWDCAgent
//
//  Created by Guilherme Rambo on 26/05/21.
//  Copyright © 2021 Guilherme Rambo. All rights reserved.
//

import Foundation

enum WWDCAppCommand {
    case toggleFavorite(_ videoId: String)
    case toggleWatched(_ videoId: String)
    case download(_ videoId: String)
    case cancelDownload(_ videoId: String)
    case revealVideo(_ videoId: String)
    case launchPreferences
}

extension WWDCAppCommand {
    
    /// `true` if the command can change user content, in which case it won't work
    /// unless the preference to enable the agent is set to on.
    var modifiesUserContent: Bool {
        switch self {
        case .toggleFavorite, .toggleWatched, .download, .cancelDownload:
            return true
        case .launchPreferences, .revealVideo:
            return false
        }
    }
    
    /// If `true`, then the app should become visible when it receives this command.
    var isForeground: Bool {
        switch self {
        case .revealVideo, .launchPreferences:
            return true
        default:
            return false
        }
    }
    
}

// MARK: - URL scheme

private enum WWDCAppCommandVerb: String {
    case toggleFavorite
    case toggleWatched
    case download
    case cancelDownload
    case revealVideo
    case launchPreferences
}

private enum WWDCAppCommandParameter: String {
    case id
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
        case .toggleFavorite(let videoId):
            return generateURL(with: .toggleFavorite, parameters: [.id: videoId])
        case .toggleWatched(let videoId):
            return generateURL(with: .toggleWatched, parameters: [.id: videoId])
        case .download(let videoId):
            return generateURL(with: .download, parameters: [.id: videoId])
        case .cancelDownload(let videoId):
            return generateURL(with: .cancelDownload, parameters: [.id: videoId])
        case .revealVideo(let videoId):
            return generateURL(with: .revealVideo, parameters: [.id: videoId])
        case .launchPreferences:
            return generateURL(with: .launchPreferences, parameters: [:])
        }
    }
    
    init?(from url: URL) {
        guard url.scheme == Self.urlScheme else { return nil }
        
        guard let host = url.host else { return nil }
        
        guard let verb = WWDCAppCommandVerb(rawValue: host) else { return nil }
        
        switch verb {
        case .toggleFavorite:
            guard let id = url.queryItemValue(for: .id) else { return nil }
            self = .toggleFavorite(id)
        case .toggleWatched:
            guard let id = url.queryItemValue(for: .id) else { return nil }
            self = .toggleWatched(id)
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
        }
    }
}

fileprivate extension URL {
    func queryItemValue(for parameter: WWDCAppCommandParameter) -> String? {
        guard let components = URLComponents(url: self, resolvingAgainstBaseURL: false) else { return nil }
        return components.queryItems?.first(where: { $0.name == parameter.rawValue })?.value
    }
}
