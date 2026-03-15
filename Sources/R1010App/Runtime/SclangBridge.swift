import Foundation

@MainActor
final class SclangBridge {
    enum BridgeError: LocalizedError {
        case commandFailed(recentLines: [String])

        var errorDescription: String? {
            switch self {
            case .commandFailed(let recentLines):
                let excerpt = recentLines.suffix(12).joined(separator: "\n")
                return """
                sclang command failed.
                Recent output:
                \(excerpt)
                """
            }
        }
    }

    private let process: MonitoredProcess

    init(process: MonitoredProcess) {
        self.process = process
    }

    func send(_ command: EngineCommand) async throws {
        let sentinel = "R1010_CMD_\(UUID().uuidString.replacingOccurrences(of: "-", with: "_"))"
        let script = command.script(sentinel: sentinel)
        let checkpoint = process.outputCheckpoint()
        try process.send(script)
        _ = try await process.waitForOutput(
            expectation: sentinel,
            timeout: 5,
            matching: { $0.contains(sentinel) }
        )

        let lines = process.outputSince(checkpoint)
        if lines.contains(where: isSuperColliderErrorLine) {
            throw BridgeError.commandFailed(recentLines: lines)
        }
    }

    private func isSuperColliderErrorLine(_ line: String) -> Bool {
        let normalized = line.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized.contains("R1010_CMD_") {
            return false
        }

        return normalized.localizedCaseInsensitiveContains("ERROR:")
            || normalized.localizedCaseInsensitiveContains("FAILURE IN SERVER")
            || normalized.localizedCaseInsensitiveContains("Message '")
    }
}
