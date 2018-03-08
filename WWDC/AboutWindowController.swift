//
//  AboutWindowController.swift
//  WWDC
//
//  Created by Guilherme Rambo on 28/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa

final class AboutWindowController: NSWindowController {

    @IBOutlet weak var backgroundView: NSVisualEffectView!
    @IBOutlet weak fileprivate var applicationNameLabel: NSTextField!
    @IBOutlet weak fileprivate var versionLabel: NSTextField!
    @IBOutlet weak var contributorsLabel: NSTextField!
    @IBOutlet weak fileprivate var creatorLabel: NSTextField!
    @IBOutlet weak fileprivate var repositoryLabel: ActionLabel!
    @IBOutlet weak fileprivate var iconCreatorLabel: ActionLabel!
    @IBOutlet weak fileprivate var uiCreatorLabel: ActionLabel!
    @IBOutlet weak fileprivate var licenseLabel: NSTextField!
    @IBOutlet weak var designContributorLabel: ActionLabel!

    var infoText: String? {
        didSet {
            guard let infoText = infoText else { return }
            contributorsLabel.stringValue = infoText
        }
    }

    convenience init(infoText: String?) {
        self.init(windowNibName: NSNib.Name(rawValue: "AboutWindowController"))
        self.infoText = infoText
    }

    override func windowDidLoad() {
        super.windowDidLoad()

        // close the window when the escape key is pressed
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard event.keyCode == 53 else { return event }

            self.closeAnimated()

            return nil
        }

        window?.collectionBehavior = [.transient, .ignoresCycle]
        window?.isMovableByWindowBackground = true
        window?.titlebarAppearsTransparent = true
        window?.titleVisibility = .hidden

        window?.appearance = WWDCAppearance.appearance()

        guard let info = Bundle.main.infoDictionary else { return }

        if let appName = info["CFBundleName"] as? String {
            applicationNameLabel.stringValue = appName
        } else {
            applicationNameLabel.stringValue = ""
        }

        if let version = info["CFBundleShortVersionString"] as? String {
            versionLabel.stringValue = "Version \(version)"
        } else {
            versionLabel.stringValue = ""
        }

        if let infoText = infoText {
            contributorsLabel.stringValue = infoText
        } else {
            contributorsLabel.stringValue = ""
        }

        if let license = info["GRBundleLicenseName"] as? String {
            licenseLabel.stringValue = "License: \(license)"
        } else {
            licenseLabel.stringValue = ""
        }

        if let creator = info["GRBundleMainDeveloperName"] as? String {
            creatorLabel.stringValue = creator
        } else {
            creatorLabel.stringValue = ""
        }

        if let repository = info["GRBundleRepositoryName"] as? String {
            repositoryLabel.stringValue = repository
        } else {
            repositoryLabel.stringValue = ""
        }

        if let website = info["GRBundleIconCreatorWebsite"] as? String {
            iconCreatorWebsite = URL(string: website)

            iconCreatorLabel.alphaValue = 0.8
            iconCreatorLabel.textColor = .primary
            iconCreatorLabel.target = self
            iconCreatorLabel.action = #selector(openIconCreatorWebsite)
        }

        if let website = info["GRBundleUserInterfaceCreatorWebsite"] as? String {
            uiCreatorWebsite = URL(string: website)

            uiCreatorLabel.alphaValue = 0.8
            uiCreatorLabel.textColor = .primary
            uiCreatorLabel.target = self
            uiCreatorLabel.action = #selector(openUserInterfaceCreatorWebsite)
        }

        if let website = info["GRBundleDesignContributorWebsite"] as? String {
            designContributorWebsite = URL(string: website)

            designContributorLabel.alphaValue = 0.8
            designContributorLabel.textColor = .primary
            designContributorLabel.target = self
            designContributorLabel.action = #selector(openDesignContributorWebsite)
        }

        if let website = info["GRBundleMainDeveloperWebsite"] as? String {
            mainDeveloperWebsite = URL(string: website)

            creatorLabel.alphaValue = 0.8
            creatorLabel.textColor = .primary
            creatorLabel.target = self
            creatorLabel.action = #selector(openMainDeveloperWebsite)
        }

        if let website = info["GRBundleRepositoryWebsite"] as? String {
            repositoryWebsite = URL(string: website)

            repositoryLabel.alphaValue = 0.8
            repositoryLabel.textColor = .primary
            repositoryLabel.target = self
            repositoryLabel.action = #selector(openRepositoryWebsite)
        }
    }

    private var iconCreatorWebsite: URL?
    private var uiCreatorWebsite: URL?
    private var mainDeveloperWebsite: URL?
    private var designContributorWebsite: URL?
    private var repositoryWebsite: URL?

    @IBAction func openIconCreatorWebsite(_ sender: Any) {
        guard let iconCreatorWebsite = iconCreatorWebsite else { return }

        NSWorkspace.shared.open(iconCreatorWebsite)
    }

    @IBAction func openUserInterfaceCreatorWebsite(_ sender: Any) {
        guard let uiCreatorWebsite = uiCreatorWebsite else { return }

        NSWorkspace.shared.open(uiCreatorWebsite)
    }

    @IBAction func openDesignContributorWebsite(_ sender: Any) {
        guard let designContributorWebsite = designContributorWebsite else { return }

        NSWorkspace.shared.open(designContributorWebsite)
    }

    @IBAction func openMainDeveloperWebsite(_ sender: Any) {
        guard let mainDeveloperWebsite = mainDeveloperWebsite else { return }

        NSWorkspace.shared.open(mainDeveloperWebsite)
    }

    @IBAction func openRepositoryWebsite(_ sender: Any) {
        guard let repositoryWebsite = repositoryWebsite else { return }

        NSWorkspace.shared.open(repositoryWebsite)
    }

    override func showWindow(_ sender: Any?) {
        window?.center()
        window?.alphaValue = 0.0

        super.showWindow(sender)

        window?.animator().alphaValue = 1.0
    }

    func closeAnimated() {
        NSAnimationContext.beginGrouping()
        NSAnimationContext.current.duration = 0.4
        NSAnimationContext.current.completionHandler = {
            self.close()
        }
        window?.animator().alphaValue = 0.0
        NSAnimationContext.endGrouping()
    }

}
