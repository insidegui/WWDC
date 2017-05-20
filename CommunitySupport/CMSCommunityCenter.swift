//
//  CMSCommunityCenter.swift
//  WWDC
//
//  Created by Guilherme Rambo on 15/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
import CloudKit

public enum CMSResult<T> {
    case success(T)
    case error(Error)
}

public final class CMSCommunityCenter: NSObject {
    
    private lazy var container: CKContainer = CKContainer.default()
    
    private lazy var database: CKDatabase = {
        return self.container.publicCloudDatabase
    }()
    
    public static let shared: CMSCommunityCenter = CMSCommunityCenter()
    
    public typealias CMSProgressBlock = (_ progress: Double) -> Void
    public typealias CMSCompletionBlock = (_ error: Error?) -> Void
    
    public override init() {
        super.init()
        
        NotificationCenter.default.addObserver(self, selector: #selector(createSubscriptionsIfNeeded), name: .NSApplicationDidFinishLaunching, object: nil)
    }
    
    public func save(model: CMSCloudKitRepresentable, progress: @escaping CMSProgressBlock, completion: @escaping CMSCompletionBlock) {
        do {
            let record = try model.makeRecord()
            
            let operation = CKModifyRecordsOperation(recordsToSave: [record], recordIDsToDelete: nil)
            
            operation.perRecordProgressBlock = { progressRecord, currentProgress in
                guard progressRecord == record else { return }
                
                DispatchQueue.main.async { progress(currentProgress) }
            }
            
            operation.modifyRecordsCompletionBlock = { _, _, error in
                let retryBlock = { self.save(model: model, progress: progress, completion: completion) }
                
                if let error = retryCloudKitOperationIfPossible(with: error, block: retryBlock) {
                    DispatchQueue.main.async { completion(error) }
                } else {
                    DispatchQueue.main.async { completion(nil) }
                }
            }
            
            database.add(operation)
        } catch {
            completion(error)
        }
    }
    
    public typealias CMSUserCompletionBlock = (_ result: CMSResult<CMSUserProfile>) -> Void
    
    public func fetchCurrentUserProfile(_ completion: @escaping CMSUserCompletionBlock) {
        let retryBlock = { self.fetchCurrentUserProfile(completion) }
            
        container.fetchUserRecordID { userRecordID, error in
            if let error = retryCloudKitOperationIfPossible(with: error, block: retryBlock) {
                DispatchQueue.main.async { completion(.error(error)) }
                return
            }
            
            guard let userRecordID = userRecordID else {
                DispatchQueue.main.async { completion(.error(CMSCloudKitError.invalidData("No record ID found"))) }
                return
            }
            
            self.database.fetch(withRecordID: userRecordID) { userRecord, error in
                if let error = retryCloudKitOperationIfPossible(with: error, block: retryBlock) {
                    DispatchQueue.main.async { completion(.error(error)) }
                    return
                }
                
                guard let userRecord = userRecord else {
                    DispatchQueue.main.async { completion(.error(CMSCloudKitError.invalidData("No user record"))) }
                    return
                }
                
                do {
                    let model = try CMSUserProfile(record: userRecord)
                    
                    DispatchQueue.main.async { completion(.success(model)) }
                } catch {
                    DispatchQueue.main.async { completion(.error(error)) }
                }
            }
        }
    }
    
    public func processNotification(userInfo: [String : Any]) -> Bool {
        // TODO: process CloudKit notification
        return false
    }
    
    @objc private func createSubscriptionsIfNeeded() {
        // TODO: create subscriptions for relevant record types
    }
    
}
