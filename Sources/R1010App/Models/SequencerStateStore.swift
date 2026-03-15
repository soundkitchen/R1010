import Foundation

@MainActor
final class SequencerStateStore: ObservableObject {
    private struct PatternPageState: Equatable {
        var stepsByVoiceID: [String: [Bool]]
    }

    private struct PatternState: Equatable {
        var pages: [PatternPageState]
    }

    private enum Constants {
        static let stepsPerPage = 16
        static let pageCount = 4
    }

    @Published var selectedPattern = "pattern A01"
    @Published var selectedPage = 1
    @Published var selectedVoiceID = VoiceRole.kick.displayName
    @Published var tempo = 128
    @Published var swing = 54
    @Published var isPlaying = false
    @Published private(set) var tracks: [VoiceTrack] = []
    @Published private var voiceDefinitions: [VoiceTrack]
    @Published private var patternBank: [String: PatternState]

    let availablePatterns = ["pattern A01", "pattern A02", "pattern A03", "pattern B01"]

    init() {
        let defaultVoices = VoiceCatalog.defaultVoices()
        voiceDefinitions = defaultVoices
        patternBank = Self.makeInitialPatternBank(
            patterns: availablePatterns,
            voices: defaultVoices
        )
        tracks = Self.buildTracks(from: defaultVoices, patternBank: patternBank, pattern: selectedPattern, page: selectedPage)
    }

    var selectedVoice: VoiceTrack? {
        tracks.first(where: { $0.id == selectedVoiceID })
    }

    var currentPatternPageSnapshot: PatternPageSnapshot {
        PatternPageSnapshot(tracks: tracks)
    }

    func selectVoice(_ id: String) {
        selectedVoiceID = id
    }

    func selectPage(_ page: Int) {
        selectedPage = min(max(page, 1), 4)
        rebuildTracks()
    }

    func selectPattern(_ pattern: String) {
        guard availablePatterns.contains(pattern) else {
            return
        }

        selectedPattern = pattern
        rebuildTracks()
    }

    func setTempo(_ bpm: Int) {
        tempo = min(max(bpm, 60), 180)
    }

    func setSwing(_ newValue: Int) {
        swing = min(max(newValue, 50), 75)
    }

    func togglePlayback() {
        isPlaying.toggle()
    }

    @discardableResult
    func toggleStep(trackID: String, stepIndex: Int) -> VoiceTrack? {
        guard stepIndex >= 0, stepIndex < Constants.stepsPerPage else {
            return nil
        }

        var bank = patternBank
        var patternState = bank[selectedPattern] ?? Self.makeEmptyPatternState(for: voiceDefinitions)
        var pageState = patternState.pages[selectedPage - 1]
        var trackSteps = pageState.stepsByVoiceID[trackID] ?? Self.emptySteps()

        trackSteps[stepIndex].toggle()
        pageState.stepsByVoiceID[trackID] = trackSteps
        patternState.pages[selectedPage - 1] = pageState
        bank[selectedPattern] = patternState
        patternBank = bank
        rebuildTracks()

        return tracks.first(where: { $0.id == trackID })
    }

    @discardableResult
    func selectEngine(_ engine: VoiceEngine, for voiceID: String) -> VoiceTrack? {
        guard let trackIndex = voiceDefinitions.firstIndex(where: { $0.id == voiceID }) else {
            return nil
        }

        var definitions = voiceDefinitions
        definitions[trackIndex].engine = engine
        let preset = VoiceCatalog.defaultPreset(for: definitions[trackIndex].role, engine: engine)
        definitions[trackIndex].presetID = preset.id
        definitions[trackIndex].parameters = preset.parameters
        voiceDefinitions = definitions
        rebuildTracks()
        return tracks.first(where: { $0.id == voiceID })
    }

    @discardableResult
    func selectPreset(_ presetID: String, for voiceID: String) -> VoiceTrack? {
        guard let trackIndex = voiceDefinitions.firstIndex(where: { $0.id == voiceID }) else {
            return nil
        }

        let track = voiceDefinitions[trackIndex]
        guard let preset = VoiceCatalog.preset(for: track.role, engine: track.engine, id: presetID) else {
            return nil
        }

        var definitions = voiceDefinitions
        definitions[trackIndex].presetID = preset.id
        definitions[trackIndex].parameters = preset.parameters
        voiceDefinitions = definitions
        rebuildTracks()
        return tracks.first(where: { $0.id == voiceID })
    }

    @discardableResult
    func updateParameter(_ key: VoiceParameterKey, value: Double, for voiceID: String) -> VoiceTrack? {
        guard let trackIndex = voiceDefinitions.firstIndex(where: { $0.id == voiceID }) else {
            return nil
        }

        var definitions = voiceDefinitions
        definitions[trackIndex].parameters[key] = value
        voiceDefinitions = definitions
        rebuildTracks()
        return tracks.first(where: { $0.id == voiceID })
    }

    func clearCurrentPage() -> [VoiceTrack] {
        var bank = patternBank
        var patternState = bank[selectedPattern] ?? Self.makeEmptyPatternState(for: voiceDefinitions)
        patternState.pages[selectedPage - 1] = Self.makeEmptyPageState(for: voiceDefinitions)
        bank[selectedPattern] = patternState
        patternBank = bank
        rebuildTracks()
        return tracks
    }

    private func rebuildTracks() {
        tracks = Self.buildTracks(
            from: voiceDefinitions,
            patternBank: patternBank,
            pattern: selectedPattern,
            page: selectedPage
        )
    }

    private static func buildTracks(
        from voices: [VoiceTrack],
        patternBank: [String: PatternState],
        pattern: String,
        page: Int
    ) -> [VoiceTrack] {
        voices.map { voice in
            var track = voice
            track.steps = steps(
                for: voice.id,
                patternBank: patternBank,
                pattern: pattern,
                page: page
            )
            return track
        }
    }

    private static func steps(
        for voiceID: String,
        patternBank: [String: PatternState],
        pattern: String,
        page: Int
    ) -> [Bool] {
        let pageIndex = page - 1
        let fallback = Self.emptySteps()

        return patternBank[pattern]?
            .pages[safe: pageIndex]?
            .stepsByVoiceID[voiceID] ?? fallback
    }

    private static func makeInitialPatternBank(
        patterns: [String],
        voices: [VoiceTrack]
    ) -> [String: PatternState] {
        var bank: [String: PatternState] = [:]

        for pattern in patterns {
            var state = makeEmptyPatternState(for: voices)

            if pattern == patterns.first {
                state.pages[0] = PatternPageState(
                    stepsByVoiceID: Dictionary(
                        uniqueKeysWithValues: voices.map { ($0.id, $0.steps) }
                    )
                )
            }

            bank[pattern] = state
        }

        return bank
    }

    private static func makeEmptyPatternState(for voices: [VoiceTrack]) -> PatternState {
        PatternState(
            pages: Array(
                repeating: makeEmptyPageState(for: voices),
                count: Constants.pageCount
            )
        )
    }

    private static func makeEmptyPageState(for voices: [VoiceTrack]) -> PatternPageState {
        PatternPageState(
            stepsByVoiceID: Dictionary(
                uniqueKeysWithValues: voices.map { ($0.id, emptySteps()) }
            )
        )
    }

    private static func emptySteps() -> [Bool] {
        Array(repeating: false, count: Constants.stepsPerPage)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else {
            return nil
        }

        return self[index]
    }
}
