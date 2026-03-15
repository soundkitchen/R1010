import Darwin
import Foundation

struct RuntimeSession: Equatable {
    enum Mode: Equatable {
        case live
        case preview
    }

    let mode: Mode
    let paths: SuperColliderPaths?
    let scsynthPort: Int?
    let bootstrapScriptURL: URL?

    var isPreview: Bool {
        mode == .preview
    }

    static func preview() -> RuntimeSession {
        RuntimeSession(
            mode: .preview,
            paths: nil,
            scsynthPort: nil,
            bootstrapScriptURL: nil
        )
    }
}

@MainActor
final class SuperColliderRuntime {
    private let preferredPorts = Array(57140...57148)
    private let fallbackPortRange = 57149...57520

    enum RuntimeError: LocalizedError {
        case alreadyRunning
        case runtimeDirectoryUnavailable
        case bootstrapFailed
        case bootstrapError(recentLines: [String])
        case bridgeUnavailable

        var errorDescription: String? {
            switch self {
            case .alreadyRunning:
                return "SuperCollider runtime is already running."
            case .runtimeDirectoryUnavailable:
                return "R-1010 runtime directory could not be prepared."
            case .bootstrapFailed:
                return "SuperCollider bootstrap script did not complete successfully."
            case .bootstrapError(let recentLines):
                let excerpt = recentLines.suffix(12).joined(separator: "\n")
                return """
                SuperCollider bootstrap reported an error.
                Recent output:
                \(excerpt)
                """
            case .bridgeUnavailable:
                return "sclang bridge is not available."
            }
        }
    }

    private let scriptBuilder = EngineScriptBuilder()
    private var scsynthProcess: MonitoredProcess?
    private var sclangProcess: MonitoredProcess?
    private var bridge: SclangBridge?
    private var currentSession: RuntimeSession?

    func start(with paths: SuperColliderPaths) async throws -> RuntimeSession {
        guard currentSession == nil else {
            throw RuntimeError.alreadyRunning
        }

        let runtimeDirectory = try prepareRuntimeDirectory()
        var lastError: Error?

        for port in candidatePorts() {
            let configuration = EngineBootstrapConfiguration(scsynthPort: port)
            let bootstrapScriptURL = try scriptBuilder.writeBootstrapScript(
                configuration: configuration,
                to: runtimeDirectory
            )
            for arguments in scsynthArgumentProfiles(for: port) {
                let scsynth = MonitoredProcess(label: "scsynth")
                let sclang = MonitoredProcess(label: "sclang")

                do {
                    try scsynth.launch(
                        executableURL: paths.scsynthURL,
                        arguments: arguments
                    )
                    _ = try await scsynth.waitForOutput(
                        expectation: "SuperCollider 3 server ready.",
                        timeout: 10,
                        matching: { $0.contains("SuperCollider 3 server ready.") }
                    )

                    try sclang.launch(executableURL: paths.sclangURL, arguments: [])
                    _ = try await sclang.waitForOutput(
                        expectation: "SuperCollider welcome banner",
                        timeout: 10,
                        matching: { $0.contains("Welcome to SuperCollider") }
                    )

                    let bootstrapCheckpoint = sclang.outputCheckpoint()
                    try sclang.send(loadCommand(for: bootstrapScriptURL))

                    let bootstrapResult = try await sclang.waitForOutput(
                        expectation: "R1010 bootstrap status",
                        timeout: 10,
                        matching: { line in
                            line.contains("R1010_BOOTSTRAP_READY") || line.contains("R1010_BOOTSTRAP_FAILED")
                        }
                    )

                    if bootstrapResult.contains("R1010_BOOTSTRAP_FAILED") {
                        throw RuntimeError.bootstrapFailed
                    }

                    let bootstrapLines = sclang.outputSince(bootstrapCheckpoint)
                    if bootstrapLines.contains(where: isSuperColliderErrorLine) {
                        throw RuntimeError.bootstrapError(recentLines: bootstrapLines)
                    }

                    self.scsynthProcess = scsynth
                    self.sclangProcess = sclang
                    self.bridge = SclangBridge(process: sclang)

                    let session = RuntimeSession(
                        mode: .live,
                        paths: paths,
                        scsynthPort: port,
                        bootstrapScriptURL: bootstrapScriptURL
                    )
                    currentSession = session
                    return session
                } catch {
                    sclang.stop()
                    scsynth.stop()
                    lastError = error

                    guard shouldRetryStartup(after: error) else {
                        throw error
                    }
                }
            }
        }

        if let lastError {
            throw lastError
        }

        throw RuntimeError.bootstrapFailed
    }

    func send(_ command: EngineCommand) async throws {
        guard let bridge else {
            throw RuntimeError.bridgeUnavailable
        }

        try await bridge.send(command)
    }

    func stop() {
        bridge = nil
        currentSession = nil
        sclangProcess?.stop()
        scsynthProcess?.stop()
        sclangProcess = nil
        scsynthProcess = nil
    }

    private func prepareRuntimeDirectory() throws -> URL {
        let appSupport = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        let directory = appSupport
            .appendingPathComponent("R-1010", isDirectory: true)
            .appendingPathComponent("Generated", isDirectory: true)

        do {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true,
                attributes: nil
            )
            return directory
        } catch {
            throw RuntimeError.runtimeDirectoryUnavailable
        }
    }

    private func scsynthArgumentProfiles(for port: Int) -> [[String]] {
        [
            ["-u", "\(port)", "-i", "0", "-I", "0", "-o", "2", "-R", "0"],
            ["-u", "\(port)", "-i", "0", "-o", "2", "-R", "0"]
        ]
    }

    private func candidatePorts() -> [Int] {
        let preferred = preferredPorts.filter(isUDPPortAvailable)
        let fallback = fallbackPortRange
            .lazy
            .filter(isUDPPortAvailable)
            .prefix(24)

        let combined = preferred + fallback
        if !combined.isEmpty {
            return combined
        }

        return preferredPorts + Array(fallbackPortRange.prefix(24))
    }

    private func shouldRetryStartup(after error: Error) -> Bool {
        let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        if message.localizedCaseInsensitiveContains("address in use")
            || message.localizedCaseInsensitiveContains("failed to open udp socket") {
            return true
        }

        switch error {
        case MonitoredProcess.ProcessError.terminated(_, _, let recentLines),
             MonitoredProcess.ProcessError.timeout(_, _, let recentLines):
            let joined = recentLines.joined(separator: "\n")
            return joined.localizedCaseInsensitiveContains("could not initialize audio")
                || joined.localizedCaseInsensitiveContains("SC_AudioDriver:")
                || joined.localizedCaseInsensitiveContains("Input Device")
                || joined.localizedCaseInsensitiveContains("Output Device")
        default:
            return false
        }
    }

    private func isSuperColliderErrorLine(_ line: String) -> Bool {
        let normalized = line.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.localizedCaseInsensitiveContains("ERROR:")
            || normalized.localizedCaseInsensitiveContains("FAILURE IN SERVER")
            || normalized.localizedCaseInsensitiveContains("Message '")
    }

    private func loadCommand(for scriptURL: URL) -> String {
        let escapedPath = scriptURL.path
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escapedPath)\".load;"
    }

    private func isUDPPortAvailable(_ port: Int) -> Bool {
        let descriptor = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard descriptor >= 0 else {
            return false
        }

        defer {
            close(descriptor)
        }

        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = in_port_t(port).bigEndian
        address.sin_addr = in_addr(s_addr: inet_addr("127.0.0.1"))

        let result = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
                bind(descriptor, socketAddress, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }

        return result == 0
    }
}
