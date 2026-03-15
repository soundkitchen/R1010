import XCTest
@testable import R1010

@MainActor
final class AppModelTests: XCTestCase {
    func testSyncSelectedPatternPageSendsSingleAtomicCommand() async {
        let runtime = RuntimeSpy()
        let bootstrap = BootstrapCoordinatorSpy()
        let appModel = AppModel(bootstrapCoordinator: bootstrap, runtime: runtime)
        let sequencer = SequencerStateStore()

        await appModel.bootstrapIfNeeded(initialState: nil)
        sequencer.selectPage(2)

        await appModel.syncSelectedPatternPage(from: sequencer)

        XCTAssertEqual(runtime.sentCommands.count, 1)
        XCTAssertEqual(runtime.sentCommands.first, .setPatternPage(sequencer.currentPatternPageSnapshot))
    }

    func testBootstrapReconcilesPlayIntentIssuedDuringBoot() async {
        let runtime = RuntimeSpy()
        runtime.shouldSuspendStart = true
        let bootstrap = BootstrapCoordinatorSpy()
        let appModel = AppModel(bootstrapCoordinator: bootstrap, runtime: runtime)
        let sequencer = SequencerStateStore()

        let bootstrapTask = Task {
            await appModel.bootstrapIfNeeded(initialState: sequencer)
        }

        await waitUntilStartSuspended(runtime)
        await appModel.togglePlayback(for: sequencer)
        runtime.resumeStart()
        await bootstrapTask.value

        XCTAssertTrue(sequencer.isPlaying)
        XCTAssertEqual(transportCommands(in: runtime.sentCommands), [.play])
    }

    func testBootstrapPreservesFinalStopIntentIssuedDuringBoot() async {
        let runtime = RuntimeSpy()
        runtime.shouldSuspendStart = true
        let bootstrap = BootstrapCoordinatorSpy()
        let appModel = AppModel(bootstrapCoordinator: bootstrap, runtime: runtime)
        let sequencer = SequencerStateStore()

        let bootstrapTask = Task {
            await appModel.bootstrapIfNeeded(initialState: sequencer)
        }

        await waitUntilStartSuspended(runtime)
        await appModel.togglePlayback(for: sequencer)
        await appModel.togglePlayback(for: sequencer)
        runtime.resumeStart()
        await bootstrapTask.value

        XCTAssertFalse(sequencer.isPlaying)
        XCTAssertTrue(transportCommands(in: runtime.sentCommands).isEmpty)
    }

    private func waitUntilStartSuspended(
        _ runtime: RuntimeSpy,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        for _ in 0..<200 {
            if runtime.isStartSuspended {
                return
            }

            await Task.yield()
        }

        XCTFail("Timed out waiting for runtime start to suspend.", file: file, line: line)
    }

    private func transportCommands(in commands: [EngineCommand]) -> [EngineCommand] {
        commands.filter { command in
            switch command {
            case .play, .stop:
                return true
            default:
                return false
            }
        }
    }
}

@MainActor
private final class BootstrapCoordinatorSpy: AppBootstrapCoordinating {
    private(set) var handledErrors: [Error] = []

    func resolvePaths() throws -> SuperColliderPaths {
        TestSupport.makePaths()
    }

    func handleLaunchFailure(_ error: Error) {
        handledErrors.append(error)
    }
}

@MainActor
private final class RuntimeSpy: RuntimeControlling {
    private(set) var sentCommands: [EngineCommand] = []
    var shouldSuspendStart = false
    private(set) var isStartSuspended = false
    private var startContinuation: CheckedContinuation<RuntimeSession, Error>?

    private let session = RuntimeSession(
        mode: .live,
        paths: TestSupport.makePaths(),
        scsynthPort: 57_140,
        bootstrapScriptURL: nil
    )

    func start(with paths: SuperColliderPaths) async throws -> RuntimeSession {
        guard shouldSuspendStart else {
            return session
        }

        isStartSuspended = true

        return try await withCheckedThrowingContinuation { continuation in
            startContinuation = continuation
        }
    }

    func send(_ command: EngineCommand) async throws {
        sentCommands.append(command)
    }

    func resumeStart() {
        guard let startContinuation else {
            return
        }

        isStartSuspended = false
        self.startContinuation = nil
        startContinuation.resume(returning: session)
    }

    func stop() {
    }
}
