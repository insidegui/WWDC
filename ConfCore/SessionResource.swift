//
//  SessionResource.swift
//  ConfCore
//
//  Created by Ben Newcombe on 09/01/2018.
//  Copyright © 2018 Guilherme Rambo. All rights reserved.
//

public enum SessionResourceType: String {
    case none
    case resource = "WWDCSessionResourceTypeResource"
    case activity = "WWDCSessionResourceTypeActivity"
}

public class SessionResource {
    public var identifier: String = ""
    public var type: SessionResourceType = .none
}
