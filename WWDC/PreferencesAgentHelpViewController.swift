//
//  PreferencesAgentHelpViewController.swift
//  WWDC
//
//  Created by Guilherme Rambo on 26/05/21.
//  Copyright © 2021 Guilherme Rambo. All rights reserved.
//

import Cocoa

final class PreferencesAgentHelpViewController: NSViewController {

    @IBOutlet weak var raycastLinkLabel: ActionLabel!
    @IBOutlet weak var githubLinkLabel: ActionLabel!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        raycastLinkLabel.textColor = .primary
        githubLinkLabel.textColor = .primary
    }
    
    @IBAction func openRaycastLink(_ sender: ActionLabel) {
        guard let url = URL(string: "https://raycast.com") else { return }
        
        NSWorkspace.shared.open(url)
    }
    
    @IBAction func openGithubLink(_ sender: ActionLabel) {
        guard let info = Bundle.main.infoDictionary else { return }
        
        guard let url = URL(string: info.stringOrEmpty(for: "GRBundleRepositoryWebsite")) else { return }
        
        NSWorkspace.shared.open(url)
    }
    
}
