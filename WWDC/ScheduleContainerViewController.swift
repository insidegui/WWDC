//
//  ScheduleContainerViewController.swift
//  WWDC
//
//  Created by Guilherme Rambo on 28/05/20.
//  Copyright © 2020 Guilherme Rambo. All rights reserved.
//

import Cocoa
import Combine

final class ScheduleContainerViewController: WWDCWindowContentViewController {

    let splitViewController: SessionsSplitViewController

    init(splitViewController: SessionsSplitViewController) {
        self.splitViewController = splitViewController

        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    /// This should be bound to a state that returns `true` when the schedule is not available.
    @Published
    var isShowingHeroView = false

    private(set) lazy var heroController: EventHeroViewController = {
        EventHeroViewController()
    }()

    override func loadView() {
        view = NSView()

        splitViewController.view.translatesAutoresizingMaskIntoConstraints = false

        addChild(splitViewController)
        view.addSubview(splitViewController.view)
        
        NSLayoutConstraint.activate([
            splitViewController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            splitViewController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            splitViewController.view.topAnchor.constraint(equalTo: view.topAnchor),
            splitViewController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        heroController.view.translatesAutoresizingMaskIntoConstraints = false
        heroController.view.isHidden = true

        addChild(heroController)
        view.addSubview(heroController.view)

        NSLayoutConstraint.activate([
            heroController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            heroController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            heroController.view.topAnchor.constraint(equalTo: view.topAnchor),
            heroController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private lazy var cancellables: Set<AnyCancellable> = []

    override func viewDidLoad() {
        super.viewDidLoad()

        bindViews()
    }

    private func bindViews() {
        $isShowingHeroView.replaceError(with: false).driveUI(\.view.isHidden, on: splitViewController)
                           .store(in: &cancellables)

        $isShowingHeroView.toggled().replaceError(with: true)
                           .driveUI(\.view.isHidden, on: heroController)
                           .store(in: &cancellables)

        $isShowingHeroView.driveUI { [weak self] _ in
            self?.view.needsUpdateConstraints = true
        }
        .store(in: &cancellables)
    }

    override var childForWindowTopSafeAreaConstraint: NSViewController? {
        isShowingHeroView ? heroController : nil
    }

}
