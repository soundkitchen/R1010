import Foundation

@MainActor
final class MonitoredProcess {
    enum ProcessError: LocalizedError {
        case notRunning(label: String)
        case missingStandardInput(label: String)
        case terminated(label: String, status: Int32, recentLines: [String])
        case timeout(label: String, expectation: String, recentLines: [String])

        var errorDescription: String? {
            switch self {
            case .notRunning(let label):
                return "\(label) process is not running."
            case .missingStandardInput(let label):
                return "\(label) process stdin is not available."
            case .terminated(let label, let status, let recentLines):
                let lines = recentLines.suffix(12).joined(separator: "\n")
                return """
                \(label) process terminated unexpectedly with status \(status).
                Recent output:
                \(lines)
                """
            case .timeout(let label, let expectation, let recentLines):
                let lines = recentLines.suffix(12).joined(separator: "\n")
                return """
                Timed out while waiting for \(label) output: \(expectation)
                Recent output:
                \(lines)
                """
            }
        }
    }

    private struct OutputWaiter {
        let expectation: String
        let predicate: (String) -> Bool
        let continuation: CheckedContinuation<String, Error>
    }

    private final class LinePump {
        private let onLine: (String) -> Void
        private var buffer = Data()
        private let newline = Data([0x0A])

        init(onLine: @escaping (String) -> Void) {
            self.onLine = onLine
        }

        func consume(_ data: Data) {
            buffer.append(data)

            while let range = buffer.range(of: newline) {
                let lineData = buffer.subdata(in: 0..<range.lowerBound)
                buffer.removeSubrange(0..<range.upperBound)

                guard let line = String(data: lineData, encoding: .utf8) else {
                    continue
                }

                onLine(line.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }
    }

    let label: String

    private let process = Process()
    private let inputPipe = Pipe()
    private let outputPipe = Pipe()
    private lazy var linePump = LinePump { [weak self] line in
        self?.handleOutputLine(line)
    }

    private var waiters: [UUID: OutputWaiter] = [:]
    private var recentLines: [String] = []
    private var totalOutputLineCount = 0
    private var terminatedStatus: Int32?

    init(label: String) {
        self.label = label
    }

    func launch(executableURL: URL, arguments: [String]) throws {
        process.executableURL = executableURL
        process.arguments = arguments
        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        outputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else {
                handle.readabilityHandler = nil
                return
            }

            Task { @MainActor in
                self?.linePump.consume(data)
            }
        }

        process.terminationHandler = { [weak self] process in
            Task { @MainActor in
                self?.handleTermination(status: process.terminationStatus)
            }
        }

        try process.run()
    }

    func send(_ input: String) throws {
        guard process.isRunning else {
            throw ProcessError.notRunning(label: label)
        }

        let data = Data((input + "\n\n").utf8)

        do {
            try inputPipe.fileHandleForWriting.write(contentsOf: data)
        } catch {
            throw ProcessError.missingStandardInput(label: label)
        }
    }

    func waitForOutput(
        expectation: String,
        timeout: TimeInterval,
        matching predicate: @escaping (String) -> Bool
    ) async throws -> String {
        if let terminatedStatus {
            throw ProcessError.terminated(label: label, status: terminatedStatus, recentLines: recentLines)
        }

        if let existingLine = recentLines.last(where: predicate) {
            return existingLine
        }

        return try await withCheckedThrowingContinuation { continuation in
            let id = UUID()
            waiters[id] = OutputWaiter(
                expectation: expectation,
                predicate: predicate,
                continuation: continuation
            )

            Task { @MainActor [weak self] in
                let nanoseconds = UInt64(timeout * 1_000_000_000)
                try? await Task.sleep(nanoseconds: nanoseconds)
                self?.timeoutWaiter(id)
            }
        }
    }

    func stop() {
        outputPipe.fileHandleForReading.readabilityHandler = nil

        if process.isRunning {
            process.terminate()
        }
    }

    func outputCheckpoint() -> Int {
        totalOutputLineCount
    }

    func outputSince(_ checkpoint: Int) -> [String] {
        let availableCount = totalOutputLineCount - checkpoint
        guard availableCount > 0 else {
            return []
        }

        return Array(recentLines.suffix(availableCount))
    }

    private func handleOutputLine(_ line: String) {
        guard !line.isEmpty else {
            return
        }

        totalOutputLineCount += 1
        recentLines.append(line)
        recentLines = Array(recentLines.suffix(80))

        let matchingIDs = waiters.compactMap { id, waiter in
            waiter.predicate(line) ? id : nil
        }

        for id in matchingIDs {
            guard let waiter = waiters.removeValue(forKey: id) else {
                continue
            }

            waiter.continuation.resume(returning: line)
        }
    }

    private func handleTermination(status: Int32) {
        terminatedStatus = status
        let error = ProcessError.terminated(label: label, status: status, recentLines: recentLines)
        let pending = waiters
        waiters.removeAll()

        for waiter in pending.values {
            waiter.continuation.resume(throwing: error)
        }
    }

    private func timeoutWaiter(_ id: UUID) {
        guard let waiter = waiters.removeValue(forKey: id) else {
            return
        }

        let error = ProcessError.timeout(
            label: label,
            expectation: waiter.expectation,
            recentLines: recentLines
        )
        waiter.continuation.resume(throwing: error)
    }
}
