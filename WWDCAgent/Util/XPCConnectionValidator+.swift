//
//  XPCConnectionValidator+.swift
//  WWDCAgent
//
//  Created by Guilherme Rambo on 02/04/20.
//  Copyright © 2020 Guilherme Rambo. All rights reserved.
//

import Foundation

public extension XPCConnectionValidator {

    static let shared: XPCConnectionValidator = {
        let requirements: String

        // Allow only certain team IDs to communicate with the agent.
        
        #if DEBUG
        // Same as production for now because we're using "organizational unit (OU)" which is the team ID,
        // but could be different if we decide to use other parts of the chain to validate.
            requirements = "anchor apple generic and (certificate leaf[subject.OU] = \"8C7439RJLG\" or certificate leaf[subject.OU] = \"SY64MV22J9\")"
        #else
            requirements = "anchor apple generic and (certificate leaf[subject.OU] = \"8C7439RJLG\" or certificate leaf[subject.OU] = \"SY64MV22J9\")"
        #endif

        guard let validator = XPCConnectionValidator(requirements: requirements) else {
            fatalError("Failed to initialize XPC connection validator with the specified requirements: \(requirements)")
        }

        return validator
    }()

}
