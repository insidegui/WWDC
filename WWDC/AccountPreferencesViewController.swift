//
//  AccountPreferencesViewController.swift
//  WWDC
//
//  Created by Guilherme Rambo on 20/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
import RxSwift
import RxCocoa
import CommunitySupport

class AccountPreferencesViewController: NSViewController, WWDCImageViewDelegate {

    private let disposeBag = DisposeBag()
    
    var profile: CMSUserProfile? {
        didSet {
            updateUI()
        }
    }
    
    var cloudAccountIsAvailable = false {
        didSet {
            updateUI()
        }
    }
    
    init() {
        super.init(nibName: nil, bundle: nil)!
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadView() {
        self.view = NSView()
        self.view.wantsLayer = true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        buildUI()
    }
    
    private lazy var avatarImageView: WWDCImageView = {
        let v = WWDCImageView()
        
        v.widthAnchor.constraint(equalToConstant: 98).isActive = true
        v.heightAnchor.constraint(equalToConstant: 98).isActive = true
        v.translatesAutoresizingMaskIntoConstraints = false
        v.isEditable = true
        v.delegate = self
        
        return v
    }()
    
    private lazy var nameLabel: NSTextField = {
        let f = NSTextField(labelWithString: "")
        
        f.font = NSFont.systemFont(ofSize: 18, weight: NSFontWeightMedium)
        f.textColor = .prefsPrimaryText
        f.translatesAutoresizingMaskIntoConstraints = false
        f.alignment = .center
        
        return f
    }()
    
    private lazy var infoLabel: WWDCTextField = {
        let help = "Your community account is used to sync your data like bookmarks,\nvideo progress and favorites. It can also be used to recommend\nsessions to other viewers and share bookmarks."
        
        let f = WWDCTextField(wrappingLabelWithString: help)
        
        f.font = NSFont.systemFont(ofSize: 14, weight: NSFontWeightRegular)
        f.textColor = .prefsSecondaryText
        f.cell?.backgroundStyle = .dark
        f.maximumNumberOfLines = 5
        f.translatesAutoresizingMaskIntoConstraints = false
        f.alignment = .center
        
        return f
    }()
    
    private lazy var permissionLabel: WWDCTextField = {
        let help = "Your profile is currently incomplete.\nDo you want to complete it with your full name?"
        
        let f = WWDCTextField(wrappingLabelWithString: help)
        
        f.font = NSFont.systemFont(ofSize: 14, weight: NSFontWeightMedium)
        f.textColor = .prefsPrimaryText
        f.cell?.backgroundStyle = .dark
        f.maximumNumberOfLines = 5
        f.translatesAutoresizingMaskIntoConstraints = false
        f.alignment = .center
        
        return f
    }()
    
    private lazy var errorLabel: NSTextField = {
        let help = "This feature requires your macOS account to have an iCloud account. Please go to System Preferences and log in to your iCloud account."
        
        let f = NSTextField(wrappingLabelWithString: help)
        
        f.font = NSFont.systemFont(ofSize: 14, weight: NSFontWeightRegular)
        f.textColor = .errorText
        f.cell?.backgroundStyle = .dark
        f.isSelectable = true
        f.lineBreakMode = .byWordWrapping
        f.setContentCompressionResistancePriority(NSLayoutPriorityDefaultLow, for: .horizontal)
        f.allowsDefaultTighteningForTruncation = true
        f.translatesAutoresizingMaskIntoConstraints = false
        f.isHidden = true
        
        return f
    }()
    
    private lazy var completeButton: NSButton = {
        let b = NSButton(title: "Complete my profile", target: self, action: #selector(completeProfile(_:)))
        
        b.keyEquivalent = "\r"
        b.translatesAutoresizingMaskIntoConstraints = false
        
        return b
    }()
    
    private func buildUI() {
        view.addSubview(nameLabel)
        view.addSubview(avatarImageView)
        view.addSubview(infoLabel)
        view.addSubview(permissionLabel)
        view.addSubview(completeButton)
        
        avatarImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        avatarImageView.topAnchor.constraint(equalTo: view.topAnchor, constant: 22).isActive = true
        
        nameLabel.centerXAnchor.constraint(equalTo: avatarImageView.centerXAnchor).isActive = true
        nameLabel.topAnchor.constraint(equalTo: avatarImageView.bottomAnchor, constant: 12).isActive = true
        
        infoLabel.centerXAnchor.constraint(equalTo: nameLabel.centerXAnchor).isActive = true
        infoLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 40).isActive = true
        
        permissionLabel.centerXAnchor.constraint(equalTo: infoLabel.centerXAnchor).isActive = true
        permissionLabel.topAnchor.constraint(equalTo: infoLabel.bottomAnchor, constant: 12).isActive = true
        
        completeButton.centerXAnchor.constraint(equalTo: permissionLabel.centerXAnchor).isActive = true
        completeButton.topAnchor.constraint(equalTo: permissionLabel.bottomAnchor, constant: 12).isActive = true
    }
    
    private var loadingView: ModalLoadingView?
    
    private func updateUI() {
        guard let profile = profile else {
            loadingView = ModalLoadingView.show(attachedTo: view)
            
            return
        }
        
        loadingView?.hide()
        
        avatarImageView.image = profile.avatar ?? #imageLiteral(resourceName: "avatar")
        avatarImageView.isRounded = true
        
        nameLabel.stringValue = profile.name
        permissionLabel.isHidden = !profile.name.isEmpty
        completeButton.isHidden = !profile.name.isEmpty
    }
    
    @objc private func completeProfile(_ sender: Any?) {
        guard let profile = profile else { return }
        
        loadingView?.show(in: view)
        
        CMSCommunityCenter.shared.promptAndUpdateUserProfileWithDiscoveredInfo(with: profile) { [weak self] newProfile, error in
            self?.loadingView?.hide()
            
            if let error = error {
                let alert = WWDCAlert.create()
                alert.messageText = "Error updating profile"
                alert.informativeText = error.localizedDescription
                alert.runModal()
            } else {
                self?.profile = newProfile
            }
        }
    }
    
    func wwdcImageView(_ imageView: WWDCImageView, didReceiveNewImageWithFileURL url: URL) {
        guard var updatedProfile = profile else { return }
        
        loadingView?.show(in: view)
        
        updatedProfile.avatarFileURL = url
        updatedProfile.avatar = imageView.image
        
        CMSCommunityCenter.shared.save(model: updatedProfile, progress: nil) { [unowned self] error in
            self.loadingView?.hide()
            
            if let error = error {
                WWDCAlert.show(with: error)
            }
        }
    }
    
}
