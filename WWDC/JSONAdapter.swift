//
//  JSONAdapter.swift
//  WWDC
//
//  Created by Guilherme Rambo on 07/06/16.
//  Copyright © 2016 Guilherme Rambo. All rights reserved.
//

import Foundation
import SwiftyJSON

protocol JSONAdapter {
    
    associatedtype ModelType
    
    static func adapt(json: JSON) -> ModelType
    
}