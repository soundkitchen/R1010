import Foundation

@MainActor
protocol AppBootstrapCoordinating {
    func resolvePaths() throws -> SuperColliderPaths
    func handleLaunchFailure(_ error: Error)
}

@MainActor
protocol RuntimeControlling {
    func start(with paths: SuperColliderPaths) async throws -> RuntimeSession
    func send(_ command: EngineCommand) async throws
    func stop()
}
