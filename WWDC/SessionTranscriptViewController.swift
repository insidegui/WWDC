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

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: MainWindowController.defaultRect.height))
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.darkWindowBackground.cgColor

        scrollView.frame = view.bounds
        tableView.frame = view.bounds

        view.heightAnchor.constraint(equalToConstant: 180).isActive = true
        view.setContentCompressionResistancePriority(.defaultLow, for: .vertical)

        view.addSubview(scrollView)

        addChild(searchController)
        searchController.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(searchController.view)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            searchController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            searchController.view.topAnchor.constraint(equalTo: view.topAnchor)
        ])

        tableView.dataSource = self
        tableView.delegate = self
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
        filteredAnnotations = annotations.filter(predicate).toArray()
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

            guard let row = filteredAnnotations.index(of: annotation) else { return }

            tableView.selectRowIndexes(IndexSet([row]), byExtendingSelection: false)
            tableView.scrollRowToVisible(row)
        }
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
