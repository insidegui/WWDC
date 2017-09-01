//
//  ContributorsFetcher.swift
//  WWDC
//
//  Created by Guilherme Rambo on 28/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
import SwiftyJSON

public final class ContributorsFetcher {

    public static let shared: ContributorsFetcher = ContributorsFetcher()

    fileprivate struct Constants {
        static let contributorsURL = "https://api.github.com/repos/insidegui/WWDC/contributors"
    }

    private let syncQueue = DispatchQueue(label: "io.wwdc.app.contributorsfetcher.sync")
    private var names = [String]()

    public var infoTextChangedCallback: (_ newText: String) -> () = { _ in }

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
                    NSLog("[ContributorsFetcher] Error fetching contributors: \(error)")
                } else {
                    NSLog("[ContributorsFetcher] Error fetching contributors: no data returned")
                }

                self.buildInfoText(self.names)

                return
            }

            self.syncQueue.async {
                self.names += self.parseResponse(data)

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

    fileprivate func parseResponse(_ data: Data) -> [String] {
        let jsonData = JSON(data: data)
        guard let contributors = jsonData.array else { return [String]() }

        var contributorNames = [String]()
        for contributor in contributors {
            if let name = contributor["login"].string {
                contributorNames.append(name)
            }
        }

        return contributorNames
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

private struct GitHubPagination {

    var first: URL?
    var next: URL?
    var previous: URL?
    var last: URL?

    private static let urlRegex = try! NSRegularExpression(pattern: "<(.*)>", options: [])
    private static let typeRegex = try! NSRegularExpression(pattern: "rel=\"(.*)\"", options: [])

    init?(linkHeader: String) {
        let links: [(URL, String)] = linkHeader.components(separatedBy: ",").flatMap { link in
            let section = link.components(separatedBy: ";")

            if section.count < 2 {
                return nil
            }

            let urlRange = NSRange(location: 0, length: section[0].characters.count)
            var urlString = GitHubPagination.urlRegex.stringByReplacingMatches(in: section[0],
                                                                               range: urlRange,
                                                                               withTemplate: "$1")
            urlString = urlString.trimmingCharacters(in: .whitespaces)

            guard let url = URL(string: urlString) else {
                return nil
            }

            let typeRange = NSRange(location: 0, length: section[1].characters.count)
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
                break;
            }
        }
    }
}
