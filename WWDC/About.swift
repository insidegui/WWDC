//
//  About.swift
//  WWDC
//
//  Created by Guilherme Rambo on 20/12/15.
//  Copyright © 2015 Guilherme Rambo. All rights reserved.
//

import Foundation
import Alamofire
import SwiftyJSON

private let _sharedAboutInfo = About()

class About {
    
    class var sharedInstance: About {
        return _sharedAboutInfo
    }

    fileprivate struct Constants {
        static let contributorsURL = "https://api.github.com/repos/insidegui/WWDC/contributors"
    }
    
    var infoTextChangedCallback: (_ newText: String) -> () = { _ in }
    var infoText = "" {
        didSet {
            mainQ {
                self.infoTextChangedCallback(self.infoText)
            }
        }
    }
    
    /// Loads the list of contributors from the GitHub repository and builds the infoText
    func load() {
        Alamofire.request(.GET, Constants.contributorsURL).responseJSON { response in
            switch response.result {
            case .Success(_):
                self.parseResponse(response)
            default:
                print("Unable to download about window contribution info")
            }
        }
    }
    
    fileprivate func parseResponse(_ response: Response<AnyObject, NSError>) {
        guard let rawData = response.data else { return }
        
        let jsonData = JSON(data: rawData)
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
