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
    func sessionRowIdentifierForToday() -> SessionIdentifiable?
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

            let titleRow = SessionRow(title: track.name)

            let sessionRows: [SessionRow] = thing.sorted(by: Session.standardSort).compactMap { session in
                guard let viewModel = SessionViewModel(session: session) else { return nil }

                return SessionRow(viewModel: viewModel)
            }

            return [titleRow] + sessionRows
        }

        return rows
    }

    func sessionRowIdentifierForToday() -> SessionIdentifiable? {
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
            var instances: [SessionInstance]

            if let included = included {
                let sessionIdentifiers = Array(included.map { $0.identifier })
                instances = Array(section.instances.filter(NSPredicate(format: "session.identifier IN %@", sessionIdentifiers)))
                guard !instances.isEmpty else { return [] }
            } else {
                instances = Array(section.instances)
            }

            // Section header
            let titleRow = SessionRow(date: section.representedDate, showTimeZone: !shownTimeZone)

            shownTimeZone = true

            let instanceRows: [SessionRow] = instances.sorted(by: SessionInstance.standardSort).compactMap { instance in
                guard let viewModel = SessionViewModel(session: instance.session, instance: instance, style: .schedule) else { return nil }

                return SessionRow(viewModel: viewModel)
            }

            return [titleRow] + instanceRows
        }

        return rows
    }

    func sessionRowIdentifierForToday() -> SessionIdentifiable? {

        guard let section = scheduleSections.filter("representedDate >= %@", today()).first else { return nil }

        guard let identifier = section.instances.first?.session?.identifier else { return nil }

        return SessionIdentifier(identifier)
    }
}
