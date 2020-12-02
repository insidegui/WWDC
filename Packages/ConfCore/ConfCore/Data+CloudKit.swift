//
//  Data+CloudKit.swift
//  ConfCore
//
//  Created by Guilherme Rambo on 24/05/18.
//  Copyright © 2018 Guilherme Rambo. All rights reserved.
//

import Foundation

extension Data {

    func writeToTempLocationForCloudKitUpload() throws -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory() + "/WWDC_CKTemp_\(UUID().uuidString)")

        try write(to: url)

        return url
    }

}
