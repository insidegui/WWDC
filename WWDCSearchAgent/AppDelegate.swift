//
//  AppDelegate.swift
//  WWDCSearchAgent
//
//  Created by Guilherme Rambo on 21/02/20.
//  Copyright © 2020 Guilherme Rambo. All rights reserved.
//

import Cocoa
import RealmSwift
import ConfCore

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    private var service: SearchService?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        do {
            let supportPath = try PathUtil.appSupportPathCreatingIfNeeded()

            let filePath = supportPath + "/ConfCore.realm"

            var realmConfig = Realm.Configuration(fileURL: URL(fileURLWithPath: filePath))
            realmConfig.schemaVersion = Constants.coreSchemaVersion

            let storage = try Storage(realmConfig)

            service = SearchService(storage: storage)
            service?.listen()
        } catch {
            fatalError("Realm initialization error: \(error)")
        }
    }

}
