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
        
        let task = URLSession.shared.dataTask(with: url) { [unowned self] data, _, error in
            guard let data = data, error == nil else {
                if let error = error {
                    NSLog("[ContributorsFetcher] Error fetching contributors: \(error)")
                } else {
                    NSLog("[ContributorsFetcher] Error fetching contributors: no data returned")
                }
                return
            }
            
            self.parseResponse(data)
        }
        
        task.resume()
    }
    
    fileprivate func parseResponse(_ data: Data) {
        let jsonData = JSON(data: data)
        guard let contributors = jsonData.array else { return }
        
        var contributorNames = [String]()
        for contributor in contributors {
            if let name = contributor["login"].string {
                contributorNames.append(name)
            }
        }
        
        buildInfoText(contributorNames)
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
