//
//  CMSCommunityCenter.swift
//  WWDC
//
//  Created by Guilherme Rambo on 15/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
import CloudKit
import RxSwift

public enum CMSResult<T> {
    case success(T)
    case error(Error)
}

public enum CMSCloudAccountStatus {
    case available
    case unavailable
}

extension Notification.Name {
    static let CMSUserProfileDidChange = Notification.Name("CMSUserProfileDidChangeNotificationName")
}

public final class CMSCommunityCenter: NSObject {
    
    private lazy var container: CKContainer = CKContainer.default()
    
    private lazy var database: CKDatabase = {
        return self.container.publicCloudDatabase
    }()
    
    public static let shared: CMSCommunityCenter = CMSCommunityCenter()
    
    public typealias CMSProgressBlock = (_ progress: Double) -> Void
    public typealias CMSCompletionBlock = (_ error: Error?) -> Void
    
    public lazy var accountStatus: Observable<CMSCloudAccountStatus> = {
        return self.createAccountStatusObservable()
    }()
    
    public lazy var userProfile: Observable<CMSUserProfile> = {
        return self.createUserProfileObservable()
    }()
    
    public override init() {
        super.init()
        
        NotificationCenter.default.addObserver(self, selector: #selector(createSubscriptionsIfNeeded), name: .NSApplicationDidFinishLaunching, object: nil)
    }
    
    public func save(model: CMSCloudKitRepresentable, progress: CMSProgressBlock?, completion: @escaping CMSCompletionBlock) {
        do {
            let record = try model.makeRecord()
            
            let operation = CKModifyRecordsOperation(recordsToSave: [record], recordIDsToDelete: nil)
            operation.savePolicy = .changedKeys
            
            if let progress = progress {
                operation.perRecordProgressBlock = { progressRecord, currentProgress in
                    guard progressRecord == record else { return }
                    
                    DispatchQueue.main.async { progress(currentProgress) }
                }
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
    
    public func profileForUser(withNickname nickname: String, completion: @escaping CMSUserCompletionBlock) {
        let predicate = NSPredicate(format: "nickname == %@", nickname)
        let query = CKQuery(recordType: CMSUserProfile.recordType, predicate: predicate)
        
        let operation = CKQueryOperation(query: query)
        
        var records: [CKRecord] = []
        
        operation.recordFetchedBlock = { record in
            records.append(record)
        }
        
        operation.queryCompletionBlock = { _, error in
            let retryBlock = { self.profileForUser(withNickname: nickname, completion: completion) }
            
            if let error = retryCloudKitOperationIfPossible(with: error, block: retryBlock) {
                let effectiveError = CMSCloudKitError.invalidData(error.localizedDescription)
                DispatchQueue.main.async { completion(.error(effectiveError)) }
                return
            }
            
            guard let record = records.first else {
                let error = CMSCloudKitError.notFound
                DispatchQueue.main.async { completion(.error(error)) }
                return
            }
            
            do {
                let profile = try CMSUserProfile(record: record)
                
                DispatchQueue.main.async { completion(.success(profile)) }
            } catch {
                DispatchQueue.main.async { completion(.error(error)) }
            }
        }
        
        database.add(operation)
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
    
    public func promptAndUpdateUserProfileWithDiscoveredInfo(with profile: CMSUserProfile, completion: @escaping (CMSUserProfile?, Error?) -> Void) {
        container.requestApplicationPermission(.userDiscoverability) { status, error in
            if let error = error {
                DispatchQueue.main.async { completion(nil, CMSCloudKitError.invalidData("Unable to request permission:\n\(error.localizedDescription)")) }
                return
            }
            
            switch status {
            case .granted:
                self.fetchUserInfo(for: profile, completion: completion)
            default: break
            }
        }
    }
    
    private func fetchUserInfo(for profile: CMSUserProfile, completion: @escaping (CMSUserProfile?, Error?) -> Void) {
        guard let record = profile.originatingRecord else {
            DispatchQueue.main.async { completion(nil, CMSCloudKitError.invalidData("Invalid profile: no originating record")) }
            return
        }
        
        container.discoverUserIdentity(withUserRecordID: record.recordID) { identity, error in
            guard let identity = identity, error == nil else {
                DispatchQueue.main.async { completion(nil, CMSCloudKitError.invalidData("Unable to get user identity")) }
                return
            }
            
            guard let nameComponents = identity.nameComponents else {
                DispatchQueue.main.async { completion(nil, CMSCloudKitError.invalidData("Unable to parse user name")) }
                return
            }
            
            let formatter = PersonNameComponentsFormatter()
            let fullName = formatter.string(from: nameComponents)
            
            self.updateUser(record: record, withName: fullName, completion: completion)
        }
    }
    
    private func updateUser(record: CKRecord, withName fullName: String, completion: @escaping (CMSUserProfile?, Error?) -> Void) {
        do {
            var newProfile = try CMSUserProfile(record: record)
            newProfile.name = fullName
            
            self.save(model: newProfile, progress: nil) { error in
                if let error = error {
                    DispatchQueue.main.async { completion(nil, CMSCloudKitError.invalidData("Unable to save profile: \(error.localizedDescription)")) }
                } else {
                    DispatchQueue.main.async { completion(newProfile, nil) }
                }
            }
        } catch {
            DispatchQueue.main.async { completion(nil, CMSCloudKitError.invalidData("Unable to save profile: \(error.localizedDescription)")) }
        }
    }
    
    // MARK: - Subscriptions
    
    public func processNotification(userInfo: [String : Any]) -> Bool {
        // TODO: process CloudKit notification
        return false
    }
    
    @objc private func createSubscriptionsIfNeeded() {
        // TODO: create subscriptions for relevant record types
    }
    
    // MARK: - Observable generators
    
    private func createAccountStatusObservable() -> Observable<CMSCloudAccountStatus> {
        return Observable<CMSCloudAccountStatus>.create { observer -> Disposable in
            let checkAccountStatus = {
                self.container.accountStatus { status, error in
                    guard error == nil else {
                        slog("Error checking CloudKit account status: \(error?.localizedDescription ?? "Unknown")")
                        observer.onNext(.unavailable)
                        return
                    }
                    
                    switch status {
                    case .available:
                        observer.onNext(.available)
                    default:
                        observer.onNext(.unavailable)
                    }
                    
                    NotificationCenter.default.post(name: .CMSUserProfileDidChange, object: nil)
                }
            }
            
            let cloudKitObserver = NotificationCenter.default.addObserver(forName: .CKAccountChanged, object: nil, queue: nil) { _ in
                checkAccountStatus()
            }
            
            checkAccountStatus()
            
            return Disposables.create { NotificationCenter.default.removeObserver(cloudKitObserver) }
        }
    }
    
    private func createUserProfileObservable() -> Observable<CMSUserProfile> {
        return Observable<CMSUserProfile>.create { observer -> Disposable in
            let profileNotificationObserver = NotificationCenter.default.addObserver(forName: .CMSUserProfileDidChange, object: nil, queue: nil) { _ in
                self.fetchCurrentUserProfile({ result in
                    switch result {
                    case .success(let profile):
                        observer.onNext(profile)
                    case .error(let error):
                        observer.onError(error)
                    }
                })
            }
            
            return Disposables.create { NotificationCenter.default.removeObserver(profileNotificationObserver) }
        }
    }
    
}
