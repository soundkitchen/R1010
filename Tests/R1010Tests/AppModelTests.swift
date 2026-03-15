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

    func start(with paths: SuperColliderPaths) async throws -> RuntimeSession {
        RuntimeSession(
            mode: .live,
            paths: paths,
            scsynthPort: 57_140,
            bootstrapScriptURL: nil
        )
    }

    func send(_ command: EngineCommand) async throws {
        sentCommands.append(command)
    }

    func stop() {
    }
}
