import Foundation

enum EngineCommand: Equatable {
    case play
    case stop
    case setTempo(Int)
    case setSwing(Int)
    case setPatternPage(PatternPageSnapshot)
    case setSteps(voiceID: String, steps: [Bool])
    case setVoiceEngine(voiceID: String, engine: String)
    case setVoicePreset(voiceID: String, presetID: String)
    case setVoiceParams(voiceID: String, parameters: VoiceParameters)
    case previewVoice(voiceID: String)

    func script(sentinel: String) -> String {
        switch self {
        case .play:
            return "~r1010CommandPlay.value(\(quotedString(sentinel)));"
        case .stop:
            return "~r1010CommandStop.value(\(quotedString(sentinel)));"
        case .setTempo(let bpm):
            return "~r1010CommandSetTempo.value(\(bpm), \(quotedString(sentinel)));"
        case .setSwing(let swing):
            return "~r1010CommandSetSwing.value(\(swing), \(quotedString(sentinel)));"
        case .setPatternPage(let snapshot):
            return "~r1010CommandSetPatternPage.value(\(patternPageSnapshotLiteral(snapshot)), \(quotedString(sentinel)));"
        case .setSteps(let voiceID, let steps):
            return "~r1010CommandSetSteps.value(\(quotedSymbol(voiceID)), \(stepArrayLiteral(steps)), \(quotedString(sentinel)));"
        case .setVoiceEngine(let voiceID, let engine):
            return "~r1010CommandSetVoiceEngine.value(\(quotedSymbol(voiceID)), \(quotedString(engine)), \(quotedString(sentinel)));"
        case .setVoicePreset(let voiceID, let presetID):
            return "~r1010CommandSetVoicePreset.value(\(quotedSymbol(voiceID)), \(quotedString(presetID)), \(quotedString(sentinel)));"
        case .setVoiceParams(let voiceID, let parameters):
            return "~r1010CommandSetVoiceParams.value(\(quotedSymbol(voiceID)), \(parameters.attack), \(parameters.decay), \(parameters.tune), \(parameters.lowPass), \(parameters.resonance), \(parameters.drive), \(quotedString(sentinel)));"
        case .previewVoice(let voiceID):
            return "~r1010CommandPreviewVoice.value(\(quotedSymbol(voiceID)), \(quotedString(sentinel)));"
        }
    }

    private func quotedString(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }

    private func quotedSymbol(_ value: String) -> String {
        "\\\(value)"
    }

    private func stepArrayLiteral(_ steps: [Bool]) -> String {
        let values = steps.map { $0 ? "1.0" : "0.0" }.joined(separator: ", ")
        return "[\(values)]"
    }

    private func patternPageSnapshotLiteral(_ snapshot: PatternPageSnapshot) -> String {
        let voices = snapshot.voices.map { voice in
            "[\(quotedSymbol(voice.voiceID)), \(stepArrayLiteral(voice.steps))]"
        }.joined(separator: ", ")
        return "[\(voices)]"
    }
}
