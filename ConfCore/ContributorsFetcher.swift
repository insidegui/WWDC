//
//  ContributorsFetcher.swift
//  WWDC
//
//  Created by Guilherme Rambo on 28/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
import os.log

public final class ContributorsFetcher {

    public static let shared: ContributorsFetcher = ContributorsFetcher()

    private let log = OSLog(subsystem: "WWDC", category: "ContributorsFetcher")

    fileprivate struct Constants {
        static let contributorsURL = "https://api.github.com/repos/insidegui/WWDC/contributors"
    }

    private let syncQueue = DispatchQueue(label: "io.wwdc.app.contributorsfetcher.sync")
    private var names = [String]()

    public var infoTextChangedCallback: (_ newText: String) -> Void = { _ in }

    public var infoText = "" {
        didSet {
            DispatchQueue.main.async {
                self.infoTextChangedCallback(self.infoText)
            }
        }
    }

    /// Loads the list of contributors from the GitHub repository and builds the infoText
    public func load() {
        guard let url = URL(string: Constants.contributorsURL) else { return }

        names = [String]()

        loadFrom(url: url)
    }

    private func loadFrom(url: URL) {
        let task = URLSession.shared.dataTask(with: url) { [unowned self] data, response, error in
            guard let data = data, error == nil else {
                if let error = error {
                    os_log("Error fetching contributors: %{public}@", log: self.log, type: .error, String(describing: error))
                } else {
                    os_log("Error fetching contributors: network call returned no data", log: self.log, type: .error)
                }

                self.buildInfoText(self.names)

                return
            }

            self.syncQueue.async {
                do {
                    self.names += try self.parseResponse(data)
                } catch {
                    os_log("Failed to decode contributors names", log: self.log, type: .error)
                }

                if let linkHeader = (response as? HTTPURLResponse)?.allHeaderFields["Link"] as? String,
                    let nextPage = GitHubPagination(linkHeader: linkHeader)?.next {
                    self.loadFrom(url: nextPage)
                } else {
                    self.buildInfoText(self.names)
                }
            }
        }

        task.resume()
    }

    fileprivate func parseResponse(_ data: Data) throws -> [String] {

        return try JSONDecoder().decode([GitHubUser].self, from: data).map { $0.login }
    }

    fileprivate func buildInfoText(_ names: [String]) {
        var text = "Contributors (GitHub usernames):\n"

        var prefix = ""
        for name in names {
            text.append("\(prefix)\(name)")
            prefix = ", "
        }

        infoText = text
    }
}

private struct GitHubUser: Codable {
    var login: String
}

private struct GitHubPagination {

    var first: URL?
    var next: URL?
    var previous: URL?
    var last: URL?

    // swiftlint:disable force_try
    // As these regex's are constants, we don't need to worry about the failures
    private static let urlRegex = try! NSRegularExpression(pattern: "<(.*)>", options: [])
    private static let typeRegex = try! NSRegularExpression(pattern: "rel=\"(.*)\"", options: [])
    // swiftlint:enable force_try

    init?(linkHeader: String) {
        let links: [(URL, String)] = linkHeader.components(separatedBy: ",").compactMap { link in
            let section = link.components(separatedBy: ";")

            if section.count < 2 {
                return nil
            }

            let urlRange = NSRange(location: 0, length: section[0].count)
            var urlString = GitHubPagination.urlRegex.stringByReplacingMatches(in: section[0],
                                                                               range: urlRange,
                                                                               withTemplate: "$1")
            urlString = urlString.trimmingCharacters(in: .whitespaces)

            guard let url = URL(string: urlString) else {
                return nil
            }

            let typeRange = NSRange(location: 0, length: section[1].count)
            var type = GitHubPagination.typeRegex.stringByReplacingMatches(in: section[1],
                                                                           range: typeRange,
                                                                           withTemplate: "$1")
            type = type.trimmingCharacters(in: .whitespaces)

            return (url, type)
        }

        for (url, type) in links {
            switch type {
            case "first":
                first = url

            case "next":
                next = url

            case "prev":
                previous = url

            case "last":
                last = url

            default:
                break
            }
        }
    }
}
