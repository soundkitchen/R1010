import Foundation

@MainActor
final class AppModel: ObservableObject {
    private enum EnvironmentKey {
        static let skipRuntimeBoot = "R1010_SKIP_RUNTIME_BOOT"
    }

    enum LaunchState: Equatable {
        case idle
        case locatingDependencies
        case startingRuntime(SuperColliderPaths)
        case ready(RuntimeSession)
        case failed
    }

    @Published private(set) var launchState: LaunchState = .idle

    private let bootstrapCoordinator: any AppBootstrapCoordinating
    private let runtime: any RuntimeControlling

    private var isRuntimePreviewEnabled: Bool {
        let value = ProcessInfo.processInfo.environment[EnvironmentKey.skipRuntimeBoot]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        switch value {
        case "1", "true", "yes", "on":
            return true
        default:
            return false
        }
    }

    init(
        bootstrapCoordinator: any AppBootstrapCoordinating = AppBootstrapCoordinator(),
        runtime: any RuntimeControlling = SuperColliderRuntime()
    ) {
        self.bootstrapCoordinator = bootstrapCoordinator
        self.runtime = runtime
    }

    var isBooting: Bool {
        switch launchState {
        case .idle, .locatingDependencies, .startingRuntime:
            return true
        case .ready, .failed:
            return false
        }
    }

    var bootMessage: String {
        switch launchState {
        case .idle, .locatingDependencies:
            return "Locating SuperCollider..."
        case .startingRuntime:
            return "Starting audio runtime..."
        case .ready(let session):
            return session.isPreview ? "Preview mode ready" : "Runtime ready"
        case .failed:
            return "Shutting down..."
        }
    }

    func statusLabel(isPlaying: Bool) -> String {
        switch launchState {
        case .idle, .locatingDependencies:
            return "booting / locating_supercollider"
        case .startingRuntime:
            return "booting / starting_runtime"
        case .ready(let session):
            let transport = isPlaying ? "playing" : "stopped"
            return session.isPreview ? "\(transport) / preview_mode" : "\(transport) / scsynth_online"
        case .failed:
            return "failed / exiting"
        }
    }

    func bootstrapIfNeeded() async {
        await bootstrapIfNeeded(initialState: nil)
    }

    func bootstrapIfNeeded(initialState: SequencerStateStore?) async {
        guard launchState == .idle else {
            return
        }

        launchState = .locatingDependencies

        if isRuntimePreviewEnabled {
            launchState = .ready(.preview())
            return
        }

        do {
            let paths = try bootstrapCoordinator.resolvePaths()
            launchState = .startingRuntime(paths)

            let session = try await runtime.start(with: paths)
            try await syncProjectStateDuringBoot(from: initialState)
            try await reconcileTransportDuringBoot(from: initialState)
            launchState = .ready(session)
        } catch {
            bootstrapCoordinator.handleLaunchFailure(error)
            launchState = .failed
        }
    }

    func syncTransport(isPlaying: Bool) async {
        await send(isPlaying ? .play : .stop)
    }

    func togglePlayback(for stateStore: SequencerStateStore?) async {
        guard let stateStore else {
            return
        }

        let shouldPlay = !stateStore.isPlaying
        stateStore.togglePlayback()

        if shouldPlay {
            await syncProjectState(from: stateStore)
        }

        await syncTransport(isPlaying: shouldPlay)
    }

    func syncTempo(_ bpm: Int) async {
        await send(.setTempo(bpm))
    }

    func syncSwing(_ swing: Int) async {
        await send(.setSwing(swing))
    }

    func syncSteps(for voice: VoiceTrack) async {
        await send(.setSteps(voiceID: voice.id, steps: voice.steps))
    }

    func syncSelectedPatternPage(from stateStore: SequencerStateStore?) async {
        guard let stateStore else {
            return
        }

        await send(.setPatternPage(stateStore.currentPatternPageSnapshot))
    }

    func syncVoiceDefinition(_ voice: VoiceTrack) async {
        await send(.setVoiceEngine(voiceID: voice.id, engine: voice.engine.rawValue))
        await send(.setVoicePreset(voiceID: voice.id, presetID: voice.presetID))
        await send(.setVoiceParams(voiceID: voice.id, parameters: voice.parameters))
    }

    func previewVoice(_ voice: VoiceTrack) async {
        await send(.previewVoice(voiceID: voice.id))
    }

    func syncProjectState(from stateStore: SequencerStateStore?) async {
        guard let stateStore else {
            return
        }

        await syncTempo(stateStore.tempo)
        await syncSwing(stateStore.swing)

        for track in stateStore.tracks {
            await syncSteps(for: track)
            await syncVoiceDefinition(track)
        }
    }

    private func syncProjectStateDuringBoot(from stateStore: SequencerStateStore?) async throws {
        guard let stateStore else {
            return
        }

        try await runtime.send(.setTempo(stateStore.tempo))
        try await runtime.send(.setSwing(stateStore.swing))

        for track in stateStore.tracks {
            try await runtime.send(.setSteps(voiceID: track.id, steps: track.steps))
            try await runtime.send(.setVoiceEngine(voiceID: track.id, engine: track.engine.rawValue))
            try await runtime.send(.setVoicePreset(voiceID: track.id, presetID: track.presetID))
            try await runtime.send(.setVoiceParams(voiceID: track.id, parameters: track.parameters))
        }
    }

    private func reconcileTransportDuringBoot(from stateStore: SequencerStateStore?) async throws {
        guard let stateStore else {
            return
        }

        var appliedIsPlaying = false

        while appliedIsPlaying != stateStore.isPlaying {
            let desiredIsPlaying = stateStore.isPlaying
            try await runtime.send(desiredIsPlaying ? .play : .stop)
            appliedIsPlaying = desiredIsPlaying
        }
    }

    private func send(_ command: EngineCommand) async {
        guard case .ready(let session) = launchState else {
            return
        }

        guard !session.isPreview else {
            return
        }

        do {
            try await runtime.send(command)
        } catch {
            bootstrapCoordinator.handleLaunchFailure(error)
            launchState = .failed
        }
    }

    func shutdown() {
        runtime.stop()
    }
}
