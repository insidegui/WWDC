//
//  WWDCAgentInterface.swift
//  WWDCAgent
//
//  Created by Guilherme Rambo on 24/05/21.
//  Copyright © 2021 Guilherme Rambo. All rights reserved.
//

import Foundation

@objc protocol WWDCAgentInterface: AnyObject {
    func testAgentConnection(with completion: @escaping (Bool) -> Void)
    func searchForSessions(matching predicate: NSPredicate, completion: @escaping ([WWDCSessionXPCObject]) -> Void)
}
