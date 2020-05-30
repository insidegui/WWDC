//
//  TranscriptSearchController.swift
//  WWDC
//
//  Created by Guilherme Rambo on 30/05/20.
//  Copyright © 2020 Guilherme Rambo. All rights reserved.
//

import Cocoa
import ConfCore
import RxSwift
import RxCocoa

final class TranscriptSearchController: NSViewController {

    private(set) var searchTerm = BehaviorRelay<String?>(value: nil)

    private lazy var searchField: NSSearchField = {
        let f = NSSearchField()

        f.translatesAutoresizingMaskIntoConstraints = false

        return f
    }()

    override func loadView() {
        view = NSView()
        view.wantsLayer = true
        view.layer?.cornerRadius = 6
        view.layer?.cornerCurve = .continuous
        view.layer?.backgroundColor = NSColor.roundedCellBackground.cgColor

        view.addSubview(searchField)

        NSLayoutConstraint.activate([
            view.heightAnchor.constraint(equalToConstant: 40),
            view.widthAnchor.constraint(equalToConstant: 226),
            searchField.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            searchField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            searchField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10)
        ])
    }

    private let disposeBag = DisposeBag()

    override func viewDidLoad() {
        super.viewDidLoad()

        searchField.rx.text.throttle(.milliseconds(500), scheduler: MainScheduler.instance)
                           .bind(to: searchTerm)
                           .disposed(by: disposeBag)
    }
    
}
