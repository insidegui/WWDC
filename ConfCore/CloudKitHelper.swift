//
//  CloudKitHelper.swift
//  WWDC
//
//  Created by Guilherme Rambo on 27/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
import CloudKit

public final class CloudKitHelper {

    public class func subscriptionExists(with name: String, in database: CKDatabase, completion: @escaping (Bool) -> Void) {
        let fetchSubscriptionOperation = CKFetchSubscriptionsOperation(subscriptionIDs: [name])

        fetchSubscriptionOperation.fetchSubscriptionCompletionBlock = { subscriptions, error in
            if error is CKError {
                DispatchQueue.main.async { completion(false) }

                return
            }

            guard let subscriptions = subscriptions else {
                return
            }

            if !subscriptions.keys.contains(name) {
                DispatchQueue.main.async { completion(false) }
            }
        }

        database.add(fetchSubscriptionOperation)
    }

}
