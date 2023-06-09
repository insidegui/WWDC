//
//  SessionRowProvider.swift
//  WWDC
//
//  Created by Allen Humphreys on 14/3/18.
//  Copyright © 2018 Guilherme Rambo. All rights reserved.
//

import ConfCore
import RealmSwift

protocol SessionRowProvider {
    func sessionRowIdentifierForToday(onlyIncludingRowsFor included: Results<Session>?) -> SessionIdentifiable?
    func filteredRows(onlyIncludingRowsFor: Results<Session>) -> [SessionRow]

    var allRows: [SessionRow] { get }
}

struct VideosSessionRowProvider: SessionRowProvider {
    private(set) var allRows = [SessionRow]()
    let tracks: Results<Track>

    init(tracks: Results<Track>) {
        self.tracks = tracks

        allRows = filteredRows(onlyIncludingRowsFor: nil)
    }

    func filteredRows(onlyIncludingRowsFor: Results<Session>) -> [SessionRow] {
        return filteredRows(onlyIncludingRowsFor: Optional.some(onlyIncludingRowsFor))
    }

    private func filteredRows(onlyIncludingRowsFor included: Results<Session>?) -> [SessionRow] {

        let rows: [SessionRow] = tracks.flatMap { track -> [SessionRow] in

            var thing = track.sessions.filter(Session.videoPredicate)

            if let included = included {
                let sessionIdentifiers = Array(included.map { $0.identifier })
                thing = thing.filter(NSPredicate(format: "identifier IN %@", sessionIdentifiers))
                guard !thing.isEmpty else { return [] }
            }

            let titleRow = SessionRow(content: .init(title: track.name, symbolName: track.symbolName))

            let sessionRows: [SessionRow] = thing.sorted(by: Session.standardSort).compactMap { session in
                guard let viewModel = SessionViewModel(session: session, track: track) else { return nil }

                return SessionRow(viewModel: viewModel)
            }

            return [titleRow] + sessionRows
        }

        return rows
    }

    func sessionRowIdentifierForToday(onlyIncludingRowsFor included: Results<Session>?) -> SessionIdentifiable? {
        return nil
    }
}

struct ScheduleSessionRowProvider: SessionRowProvider {
    private(set) var allRows = [SessionRow]()
    let scheduleSections: Results<ScheduleSection>

    init(scheduleSections: Results<ScheduleSection>) {
        self.scheduleSections = scheduleSections

        allRows = filteredRows(onlyIncludingRowsFor: nil)
    }

    func filteredRows(onlyIncludingRowsFor: Results<Session>) -> [SessionRow] {
        return filteredRows(onlyIncludingRowsFor: Optional.some(onlyIncludingRowsFor))
    }

    private func filteredRows(onlyIncludingRowsFor included: Results<Session>?) -> [SessionRow] {
        // Only show the timezone on the first section header
        var shownTimeZone = false

        let rows: [SessionRow] = scheduleSections.flatMap { section -> [SessionRow] in
            let filteredInstances = filteredInstances(in: section, onlyIncludingRowsFor: included).sorted(by: SessionInstance.standardSort)
            guard !filteredInstances.isEmpty else { return []}

            let instanceRows: [SessionRow] = filteredInstances.compactMap { instance in
                guard let viewModel = SessionViewModel(session: instance.session, instance: instance, track: nil, style: .schedule) else { return nil }

                return SessionRow(viewModel: viewModel)
            }

            // Section header
            let titleRow = SessionRow(date: section.representedDate, showTimeZone: !shownTimeZone)

            shownTimeZone = true

            return [titleRow] + instanceRows
        }

        return rows
    }

    func sessionRowIdentifierForToday(onlyIncludingRowsFor included: Results<Session>?) -> SessionIdentifiable? {

        guard let section = scheduleSections.filter("representedDate >= %@", today()).first else { return nil }

        let filteredInstances = filteredInstances(in: section, onlyIncludingRowsFor: included).sorted(by: SessionInstance.standardSort)

        guard let identifier = filteredInstances.first?.session?.identifier else { return nil }

        return SessionIdentifier(identifier)
    }

    private func filteredInstances(in section: ScheduleSection, onlyIncludingRowsFor included: Results<Session>?) -> [SessionInstance] {
        if let included = included {
            let sessionIdentifiers = Array(included.map { $0.identifier })
            return Array(section.instances.filter(NSPredicate(format: "session.identifier IN %@", sessionIdentifiers)))
        } else {
            return Array(section.instances)
        }
    }
}
