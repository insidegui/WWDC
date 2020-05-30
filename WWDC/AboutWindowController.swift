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
    @IBOutlet weak fileprivate var creatorLabel: ActionLabel!
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
        self.init(windowNibName: "AboutWindowController")
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

        guard let info = Bundle.main.infoDictionary else { return }

        configureUIFor(infoDictionary: info)
    }

    func configureUIFor(infoDictionary info: [String: Any]) {

        applicationNameLabel.stringValue = info.stringOrEmpty(for: "CFBundleName")
        versionLabel.stringValue = info.stringOrEmpty(for: "CFBundleShortVersionString")
        contributorsLabel.stringValue = infoText ?? ""
        licenseLabel.stringValue = info.stringOrEmpty(for: "GRBundleLicenseName")
        creatorLabel.stringValue = info.stringOrEmpty(for: "GRBundleMainDeveloperName")
        repositoryLabel.stringValue = info.stringOrEmpty(for: "GRBundleRepositoryName")

        iconCreatorWebsite = URL(string: info.stringOrEmpty(for: "GRBundleIconCreatorWebsite"))
        uiCreatorWebsite = URL(string: info.stringOrEmpty(for: "GRBundleUserInterfaceCreatorWebsite"))
        designContributorWebsite = URL(string: info.stringOrEmpty(for: "GRBundleDesignContributorWebsite"))
        mainDeveloperWebsite = URL(string: info.stringOrEmpty(for: "GRBundleMainDeveloperWebsite"))
        repositoryWebsite = URL(string: info.stringOrEmpty(for: "GRBundleRepositoryWebsite"))

        configureActionLabel(iconCreatorLabel, selector: #selector(openIconCreatorWebsite))
        configureActionLabel(uiCreatorLabel, selector: #selector(openUserInterfaceCreatorWebsite))
        configureActionLabel(designContributorLabel, selector: #selector(openDesignContributorWebsite))
        configureActionLabel(creatorLabel, selector: #selector(openMainDeveloperWebsite))
        configureActionLabel(repositoryLabel, selector: #selector(openRepositoryWebsite))
    }

    func configureActionLabel(_ label: ActionLabel, selector: Selector) {
        label.alphaValue = 0.8
        label.textColor = .primary
        label.target = self
        label.action = selector
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

fileprivate extension Dictionary where Key == String, Value == Any {

    func stringOrEmpty(for key: String) -> String {

        return (self[key] as? String) ?? ""
    }
}
