//
//  SessionDetailsViewController.swift
//  WWDC
//
//  Created by Guilherme Rambo on 22/04/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
import RxSwift
import RxCocoa

class SessionDetailsViewController: NSViewController {

    private let disposeBag = DisposeBag()
    
    let listStyle: SessionsListStyle
    
    var viewModel: SessionViewModel? = nil {
        didSet {
            self.shelfController.viewModel = viewModel
            self.summaryController.viewModel = viewModel
            
            if viewModel?.identifier != oldValue?.identifier {
                self.transcriptController.viewModel = viewModel
                
                showOverview()
            }
        }
    }
    
    private lazy var overviewButton: WWDCTextButton = {
        let b = WWDCTextButton()
        
        b.title = "Overview"
        b.state = NSOnState
        b.target = self
        b.action = #selector(tabButtonAction(_:))
        
        return b
    }()
    
    private lazy var transcriptButton: WWDCTextButton = {
        let b = WWDCTextButton()
        
        b.title = "Transcript"
        b.state = NSOffState
        b.target = self
        b.action = #selector(tabButtonAction(_:))
        
        return b
    }()
    
    private lazy var bookmarksButton: WWDCTextButton = {
        let b = WWDCTextButton()
        
        b.title = "Bookmarks"
        b.state = NSOffState
        b.target = self
        b.action = #selector(tabButtonAction(_:))
        
        return b
    }()
    
    private lazy var buttonsStackView: NSStackView = {
        let v = NSStackView(views: [
            self.overviewButton,
            self.transcriptButton,
            self.bookmarksButton
            ])
        
        v.orientation = .horizontal
        v.alignment = .centerY
        v.spacing = 40
        
        return v
    }()
    
    private lazy var menuButtonsContainer: WWDCBottomBorderView = {
        let v = WWDCBottomBorderView()
        
        v.wantsLayer = true
        
        v.heightAnchor.constraint(equalToConstant: 50).isActive = true
        
        v.addSubview(self.buttonsStackView)
        
        self.buttonsStackView.centerYAnchor.constraint(equalTo: v.centerYAnchor).isActive = true
        self.buttonsStackView.centerXAnchor.constraint(equalTo: v.centerXAnchor).isActive = true
        
        return v
    }()
    
    private lazy var contentView: NSView = {
        let v = NSView()
        
        v.wantsLayer = true
        
        return v
    }()
    
    private lazy var mainStackView: NSStackView = {
        let v = NSStackView(views: [self.menuButtonsContainer, self.contentView])
        
        v.orientation = .vertical
        v.spacing = 20
        v.alignment = .leading
        v.distribution = .fill
        
        return v
    }()
    
    let shelfController: ShelfViewController
    let summaryController: SessionSummaryViewController
    let transcriptController: TranscriptTableViewController
    
    init(listStyle: SessionsListStyle) {
        self.listStyle = listStyle
        
        self.shelfController = ShelfViewController()
        self.summaryController = SessionSummaryViewController()
        self.transcriptController = TranscriptTableViewController()
        
        super.init(nibName: nil, bundle: nil)!
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private var currentTabContentView: NSView? {
        didSet {
            oldValue?.removeFromSuperview()
            
            if let newView = currentTabContentView {
                newView.autoresizingMask = [.viewWidthSizable, .viewHeightSizable]
                newView.frame = contentView.frame
                
                contentView.addSubview(newView)
            }
        }
    }
    
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: MainWindowController.defaultRect.width - 300, height: MainWindowController.defaultRect.height))
        view.wantsLayer = true
        
        shelfController.view.translatesAutoresizingMaskIntoConstraints = false
        mainStackView.translatesAutoresizingMaskIntoConstraints = false
        
        shelfController.view.heightAnchor.constraint(greaterThanOrEqualToConstant: 400).isActive = true
        
        view.addSubview(shelfController.view)
        view.addSubview(mainStackView)
        
        shelfController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 46).isActive = true
        shelfController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -46).isActive = true
        shelfController.view.topAnchor.constraint(equalTo: view.topAnchor, constant: 22).isActive = true
        
        mainStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 46).isActive = true
        mainStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -46).isActive = true
        mainStackView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -46).isActive = true
        
        shelfController.view.bottomAnchor.constraint(equalTo: mainStackView.topAnchor, constant: 0).isActive = true
        
        showOverview()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    @objc private func tabButtonAction(_ sender: WWDCTextButton) {
        if sender == overviewButton {
            showOverview()
        } else if sender == transcriptButton {
            showTranscript()
        } else if sender == bookmarksButton {
            showBookmarks()
        }
    }
    
    func showOverview() {
        overviewButton.state = NSOnState
        transcriptButton.state = NSOffState
        bookmarksButton.state = NSOffState
        
        currentTabContentView = summaryController.view
    }
    
    func showTranscript() {
        transcriptButton.state = NSOnState
        overviewButton.state = NSOffState
        bookmarksButton.state = NSOffState
        
        currentTabContentView = transcriptController.view
    }
    
    func showBookmarks() {
        bookmarksButton.state = NSOnState
        overviewButton.state = NSOffState
        transcriptButton.state = NSOffState
    }
    
}
