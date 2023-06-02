import Cocoa
import OSLog

/// Handles removal of the legacy `WWDCAgent` helper process,
/// which is no longer available but may cause database migration
/// issues on first launch of version 7.4.
struct WWDCAgentRemover {

    private static let logger = Logger(subsystem: "io.wwdc.app", category: "WWDCAgentRemover")

    private static let agentBundleID = "io.wwdc.app.WWDCAgent"

    private static let agentLaunchdServiceID: String = { "gui/\(getuid())/\(agentBundleID)" }()

    private static var performedLegacyAgentRemoval: Bool {
        get { UserDefaults.standard.bool(forKey: #function) }
        set {
            UserDefaults.standard.set(newValue, forKey: #function)
            UserDefaults.standard.synchronize()
        }
    }

    static func removeWWDCAgentIfNeeded() {
        guard !performedLegacyAgentRemoval else { return }

        /// Set the flag regardless of the removal result.
        /// The idea is to avoid potential launch issues caused
        /// by repeated attempts in case removal fails for some obscure reason.
        defer { performedLegacyAgentRemoval = true }

        guard let agent = NSRunningApplication.runningApplications(withBundleIdentifier: agentBundleID).first else {
            logger.debug("Couldn't find \(agentBundleID, privacy: .public) process, skipping legacy agent removal")
            return
        }

        unregisterAgent()

        guard !agent.isTerminated else {
            logger.debug("Legacy agent process is present, but already terminated")
            return
        }

        if !agent.forceTerminate() {
            logger.warning("Force terminate failed for \(agentBundleID, privacy: .public)")
        } else {
            logger.debug("Successfully terminated legacy agent")
        }
    }

    private static func unregisterAgent() {
        logger.debug("Requesting removal of service \(agentLaunchdServiceID, privacy: .public)")

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        proc.arguments = [
            "bootout",
            agentLaunchdServiceID
        ]
        let outPipe = Pipe()
        let errPipe = Pipe()
        proc.standardOutput = outPipe
        proc.standardError = errPipe

        do {
            try proc.run()

            proc.waitUntilExit()

            guard proc.terminationStatus == 0 else {
                let output = (try? errPipe.fileHandleForReading.readToEnd().flatMap { String(decoding: $0, as: UTF8.self) }) ?? "<nil>"
                logger.error("launchctl operation failed with exit code \(proc.terminationStatus, privacy: .public): \(output, privacy: .public)")
                return
            }

            logger.debug("launchctl operation succeeded")
        } catch {
            logger.fault("Failed to run launchctl: \(error, privacy: .public)")
        }
    }

}
