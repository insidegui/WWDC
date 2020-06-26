//
//  SessionTranscriptViewController.swift
//  WWDC
//
//  Created by Guilherme Rambo on 28/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
import ConfCore
import RealmSwift
import RxSwift
import RxCocoa

extension Notification.Name {
    static let TranscriptControllerDidSelectAnnotation = Notification.Name("TranscriptControllerDidSelectAnnotation")
}

final class SessionTranscriptViewController: NSViewController {

    var viewModel: SessionViewModel? {
        didSet {
            guard viewModel?.identifier != oldValue?.identifier else { return }

            updateUI()
        }
    }

    init() {
        super.init(nibName: nil, bundle: nil)

        identifier = NSUserInterfaceItemIdentifier(rawValue: "transcriptList")
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var preferredMaximumSize: NSSize { NSSize(width: Int.max, height: Int.max) }

    lazy var tableView: WWDCTableView = {
        let v = WWDCTableView()

        v.wantsLayer = true
        v.focusRingType = .none
        v.allowsMultipleSelection = true
        v.backgroundColor = .clear
        v.headerView = nil
        v.rowHeight = 36
        v.autoresizingMask = [.width, .height]
        v.floatsGroupRows = true

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(rawValue: "transcript"))
        v.addTableColumn(column)

        return v
    }()

    lazy var scrollView: NSScrollView = {
        let v = NSScrollView()

        v.focusRingType = .none
        v.backgroundColor = .clear
        v.drawsBackground = false
        v.borderType = .noBorder
        v.documentView = self.tableView
        v.hasVerticalScroller = true
        v.hasHorizontalScroller = false
        v.translatesAutoresizingMaskIntoConstraints = false

        return v
    }()

    private lazy var searchController = TranscriptSearchController()

    var showsNewWindowButton: Bool {
        get { searchController.showsNewWindowButton }
        set { searchController.showsNewWindowButton = newValue }
    }

    private lazy var heightConstraint: NSLayoutConstraint = {
        view.heightAnchor.constraint(equalToConstant: 180)
    }()

    var enforcesHeight: Bool = true {
        didSet {
            heightConstraint.isActive = enforcesHeight
        }
    }

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: MainWindowController.defaultRect.height))
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.darkWindowBackground.cgColor

        scrollView.frame = view.bounds
        tableView.frame = view.bounds

        heightConstraint.isActive = enforcesHeight
        view.setContentCompressionResistancePriority(.defaultLow, for: .vertical)

        view.addSubview(scrollView)

        addChild(searchController)
        searchController.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(searchController.view)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        constrainSearchBar()

        tableView.dataSource = self
        tableView.delegate = self

        searchController.didSelectOpenInNewWindow = { [weak self] in self?.detachWindow() }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        NotificationCenter.default.addObserver(self, selector: #selector(highlightTranscriptLine), name: .HighlightTranscriptAtCurrentTimecode, object: nil)
    }

    private var disposeBag = DisposeBag()

    private lazy var annotations = List<TranscriptAnnotation>()
    private lazy var filteredAnnotations: [TranscriptAnnotation] = []

    private func updateUI() {
        guard let viewModel = viewModel else { return }

        disposeBag = DisposeBag()

        viewModel.rxTranscriptAnnotations.observeOn(MainScheduler.instance)
                                         .subscribe(onNext: { [weak self] annotations in
            self?.updateAnnotations(with: annotations)
        }).disposed(by: disposeBag)

        searchController.searchTerm.subscribe(onNext: { [weak self] term in
            self?.updateFilter(with: term)
        }).disposed(by: disposeBag)
    }

    private func updateAnnotations(with newAnnotations: List<TranscriptAnnotation>) {
        annotations = newAnnotations
        updateFilter(with: searchController.searchTerm.value)
    }

    private func updateFilter(with term: String?) {
        defer { tableView.reloadData() }

        guard let term = term, !term.isEmpty else {
            filteredAnnotations = annotations.toArray()
            return
        }

        let predicate = NSPredicate(format: "body CONTAINS[cd] %@", term)
        if annotations.realm == nil {
            filteredAnnotations = []
        } else {
            filteredAnnotations = annotations.filter(predicate).toArray()
        }
    }

    fileprivate var selectionLocked = false

    fileprivate func withTableViewSelectionLocked(then executeBlock: () -> Void) {
        selectionLocked = true

        executeBlock()

        perform(#selector(unlockTableViewSelection), with: nil, afterDelay: 0)
    }

    @objc fileprivate func unlockTableViewSelection() {
        selectionLocked = false
    }

    @objc private func highlightTranscriptLine(_ note: Notification) {
        withTableViewSelectionLocked {
            guard let timecode = note.object as? String else { return }

            guard let annotation = filteredAnnotations.first(where: { Transcript.roundedStringFromTimecode($0.timecode) == timecode }) else {
                return
            }

            guard let row = filteredAnnotations.firstIndex(of: annotation) else { return }

            tableView.selectRowIndexes(IndexSet([row]), byExtendingSelection: false)
            tableView.scrollRowToVisible(row)
        }
    }

    var searchStyle: TranscriptSearchController.Style {
        get { searchController.style }
        set {
            searchController.style = newValue
            constrainSearchBar()
        }
    }

    private lazy var searchBarLeadingConstraint: NSLayoutConstraint = {
        searchController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor)
    }()

    private func constrainSearchBar() {
        NSLayoutConstraint.activate([
            searchController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            searchController.view.topAnchor.constraint(equalTo: view.topAnchor)
        ])

        searchBarLeadingConstraint.isActive = searchStyle == .fullWidth

        scrollView.automaticallyAdjustsContentInsets = searchStyle == .corner

        if searchStyle == .fullWidth {
            scrollView.contentInsets = NSEdgeInsets(top: TranscriptSearchController.height, left: 0, bottom: 0, right: 0)
        } else {
            scrollView.contentInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        }
    }

    // MARK: - Detached presentation

    private var detachedWindowController: SessionTranscriptWindowController?

    func detachWindow() {
        if detachedWindowController == nil {
            detachedWindowController = SessionTranscriptWindowController()
        }

        detachedWindowController?.showWindow(self)
        detachedWindowController?.viewModel = viewModel
    }

}

extension SessionTranscriptViewController: NSTableViewDataSource, NSTableViewDelegate {

    private struct Constants {
        static let cellIdentifier = "annotation"
        static let rowIdentifier = "row"
    }

    func numberOfRows(in tableView: NSTableView) -> Int { filteredAnnotations.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        var cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: Constants.cellIdentifier), owner: tableView) as? TranscriptTableCellView

        if cell == nil {
            cell = TranscriptTableCellView(frame: .zero)
            cell?.identifier = NSUserInterfaceItemIdentifier(rawValue: Constants.cellIdentifier)
        }

        cell?.annotation = filteredAnnotations[row]

        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        guard !selectionLocked else { return }

        guard tableView.selectedRow >= 0 && tableView.selectedRow < filteredAnnotations.count else { return }

        guard let transcript = viewModel?.session.transcript() else { return }

        let row = tableView.selectedRow

        let notificationObject = (transcript, filteredAnnotations[row])

        NotificationCenter.default.post(name: NSNotification.Name.TranscriptControllerDidSelectAnnotation, object: notificationObject)
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        var rowView = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: Constants.rowIdentifier), owner: tableView) as? WWDCTableRowView

        if rowView == nil {
            rowView = WWDCTableRowView(frame: .zero)
            rowView?.identifier = NSUserInterfaceItemIdentifier(rawValue: Constants.rowIdentifier)
        }

        return rowView
    }

}
