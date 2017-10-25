//
//  RemoteEnvironment.swift
//  WWDC
//
//  Created by Guilherme Rambo on 21/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Foundation
import CloudKit
import ConfCore

final class RemoteEnvironment: NSObject {

    private struct Constants {
        static let environmentRecordType = "Environment"
        static let subscriptionDefaultsName = "remoteEnvironmentSubscriptionID"
    }

    private lazy var container: CKContainer = CKContainer.default()
    private lazy var database: CKDatabase = {
        return self.container.publicCloudDatabase
    }()

    static let shared: RemoteEnvironment = RemoteEnvironment()

    func start() {
        #if ICLOUD
            guard !Arguments.disableRemoteEnvironment else { return }

            fetch()
            createSubscriptionIfNeeded()
        #endif
    }

    private func fetch() {
        #if ICLOUD
            let query = CKQuery(recordType: Constants.environmentRecordType, predicate: NSPredicate(value: true))

            let operation = CKQueryOperation(query: query)

            operation.recordFetchedBlock = { record in
                guard let env = Environment(record) else {
                    NSLog("Error parsing remote environment")
                    return
                }

                Environment.setCurrent(env)
            }

            operation.queryCompletionBlock = { [unowned self] _, error in
                if let error = error {
                    NSLog("Error fetching remote environment: \(error)")

                    DispatchQueue.main.asyncAfter(deadline: .now() + 10) { self.fetch() }
                }
            }

            database.add(operation)
        #endif
    }

    private let environmentSubscriptionID = "REMOTE-ENVIRONMENT"

    private func createSubscriptionIfNeeded() {
        CloudKitHelper.subscriptionExists(with: environmentSubscriptionID, in: database) { [unowned self] exists in
            if !exists {
                self.doCreateSubscription()
            }
        }
    }

    private func doCreateSubscription() {
        let options: CKQuerySubscriptionOptions = [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion]
        let subscription = CKQuerySubscription(recordType: Constants.environmentRecordType,
                                               predicate: NSPredicate(value: true),
                                               subscriptionID: environmentSubscriptionID,
                                               options: options)

        database.save(subscription) { _, error in
            if let error = error {
                NSLog("[RemoteEnvironment] Error creating subscription: \(error)")
            }
        }
    }

    func processSubscriptionNotification(with userInfo: [String : Any]) -> Bool {
        let notification = CKNotification(fromRemoteNotificationDictionary: userInfo)

        // check if the remote notification is for us, if not, tell the caller that we haven't handled it
        guard notification.subscriptionID == environmentSubscriptionID else { return false }

        // notification for environment change
        fetch()

        return true
    }

}

extension Environment {

    init?(_ record: CKRecord) {
        guard let baseURLStr = record["baseURL"] as? String, URL(string: baseURLStr) != nil else { return nil }

        baseURL = baseURLStr
        videosPath = "/videos.json"
        liveVideosPath = "/videos_live.json"
        newsPath = "/news.json"
        sessionsPath = "/sessions.json"
    }

}
