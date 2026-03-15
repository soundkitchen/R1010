import Foundation

enum VoiceRole: String, CaseIterable, Identifiable {
    case kick
    case snare
    case clap
    case closedHat
    case openHat

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .kick:
            return "kick_1"
        case .snare:
            return "snare_2"
        case .clap:
            return "clap"
        case .closedHat:
            return "closed_hat"
        case .openHat:
            return "open_hat"
        }
    }

    var allowedEngines: [VoiceEngine] {
        switch self {
        case .kick:
            return [.analog, .fm, .sample]
        case .snare:
            return [.analog, .noise, .fm, .sample]
        case .clap:
            return [.noise, .sample]
        case .closedHat, .openHat:
            return [.metal, .noise, .sample]
        }
    }
}

enum VoiceEngine: String, CaseIterable, Identifiable {
    case analog
    case fm
    case sample
    case noise
    case metal

    var id: String { rawValue }

    var title: String { rawValue }
}

enum VoiceParameterKey: String, CaseIterable, Identifiable {
    case attack
    case decay
    case tune
    case lowPass
    case resonance
    case drive

    var id: String { rawValue }

    var title: String {
        switch self {
        case .attack:
            return "attack"
        case .decay:
            return "decay"
        case .tune:
            return "tune"
        case .lowPass:
            return "low pass"
        case .resonance:
            return "resonance"
        case .drive:
            return "drive"
        }
    }

    var range: ClosedRange<Double> {
        switch self {
        case .attack:
            return 0.0...120.0
        case .decay:
            return 20.0...1400.0
        case .tune:
            return -24.0...24.0
        case .lowPass:
            return 240.0...14_000.0
        case .resonance:
            return 0.10...1.20
        case .drive:
            return 0.0...1.0
        }
    }

    func clamp(_ value: Double) -> Double {
        min(max(value, range.lowerBound), range.upperBound)
    }

    func formatted(_ value: Double) -> String {
        switch self {
        case .attack, .decay:
            return "\(Int(value.rounded())) ms"
        case .tune:
            return String(format: "%+.1f st", value)
        case .lowPass:
            if value >= 1000 {
                return String(format: "%.1f kHz", value / 1000.0)
            }
            return "\(Int(value.rounded())) Hz"
        case .resonance:
            return String(format: "%.2f", value)
        case .drive:
            return String(format: "%.2f", value)
        }
    }
}

struct VoiceParameters: Equatable {
    var attack: Double
    var decay: Double
    var tune: Double
    var lowPass: Double
    var resonance: Double
    var drive: Double

    subscript(key: VoiceParameterKey) -> Double {
        get {
            switch key {
            case .attack:
                return attack
            case .decay:
                return decay
            case .tune:
                return tune
            case .lowPass:
                return lowPass
            case .resonance:
                return resonance
            case .drive:
                return drive
            }
        }
        set {
            switch key {
            case .attack:
                attack = key.clamp(newValue)
            case .decay:
                decay = key.clamp(newValue)
            case .tune:
                tune = key.clamp(newValue)
            case .lowPass:
                lowPass = key.clamp(newValue)
            case .resonance:
                resonance = key.clamp(newValue)
            case .drive:
                drive = key.clamp(newValue)
            }
        }
    }
}

struct VoicePresetDefinition: Identifiable, Equatable {
    let id: String
    let name: String
    let role: VoiceRole
    let engine: VoiceEngine
    let parameters: VoiceParameters
}

struct VoiceTrack: Identifiable, Equatable {
    let id: String
    let role: VoiceRole
    let name: String
    var steps: [Bool]
    var engine: VoiceEngine
    var presetID: String
    var parameters: VoiceParameters

    var allowedEngines: [VoiceEngine] {
        role.allowedEngines
    }

    var presets: [VoicePresetDefinition] {
        VoiceCatalog.presets(for: role, engine: engine)
    }

    var presetName: String {
        VoiceCatalog.preset(for: role, engine: engine, id: presetID)?.name ?? presetID
    }
}

enum VoiceCatalog {
    static func defaultVoices() -> [VoiceTrack] {
        [
            makeVoice(role: .kick, activeSteps: [1, 7, 13], engine: .analog, presetID: "kick-round"),
            makeVoice(role: .snare, activeSteps: [4, 10], engine: .analog, presetID: "snare-snap"),
            makeVoice(role: .clap, activeSteps: [4, 10], engine: .noise, presetID: "clap-wide"),
            makeVoice(role: .closedHat, activeSteps: [2, 6, 10, 14], engine: .metal, presetID: "hat-tight"),
            makeVoice(role: .openHat, activeSteps: [9, 13], engine: .metal, presetID: "hat-open")
        ]
    }

    static func presets(for role: VoiceRole, engine: VoiceEngine) -> [VoicePresetDefinition] {
        switch (role, engine) {
        case (.kick, .analog):
            return [
                preset(id: "kick-round", name: "round", role: role, engine: engine, parameters: .init(attack: 2, decay: 420, tune: -2, lowPass: 7_800, resonance: 0.22, drive: 0.14)),
                preset(id: "kick-punch", name: "punch", role: role, engine: engine, parameters: .init(attack: 4, decay: 280, tune: 0, lowPass: 8_400, resonance: 0.28, drive: 0.26)),
                preset(id: "kick-sub", name: "sub", role: role, engine: engine, parameters: .init(attack: 6, decay: 610, tune: -6, lowPass: 5_400, resonance: 0.18, drive: 0.08)),
                preset(id: "kick-hard", name: "hard", role: role, engine: engine, parameters: .init(attack: 1, decay: 250, tune: 2, lowPass: 9_800, resonance: 0.34, drive: 0.38))
            ]
        case (.kick, .fm):
            return [
                preset(id: "kick-fm-sub", name: "sub", role: role, engine: engine, parameters: .init(attack: 3, decay: 360, tune: -4, lowPass: 6_600, resonance: 0.20, drive: 0.18)),
                preset(id: "kick-fm-broken", name: "broken", role: role, engine: engine, parameters: .init(attack: 2, decay: 300, tune: 3, lowPass: 10_600, resonance: 0.44, drive: 0.42))
            ]
        case (.kick, .sample):
            return [
                preset(id: "kick-sample-dusty", name: "dusty", role: role, engine: engine, parameters: .init(attack: 1, decay: 440, tune: -1, lowPass: 6_800, resonance: 0.16, drive: 0.12)),
                preset(id: "kick-sample-punch", name: "hard", role: role, engine: engine, parameters: .init(attack: 1, decay: 260, tune: 1, lowPass: 9_400, resonance: 0.20, drive: 0.28))
            ]
        case (.snare, .analog):
            return [
                preset(id: "snare-snap", name: "snap", role: role, engine: engine, parameters: .init(attack: 3, decay: 260, tune: 1, lowPass: 8_800, resonance: 0.32, drive: 0.18)),
                preset(id: "snare-tight", name: "tight", role: role, engine: engine, parameters: .init(attack: 2, decay: 190, tune: 3, lowPass: 10_200, resonance: 0.26, drive: 0.12))
            ]
        case (.snare, .noise):
            return [
                preset(id: "snare-noise-wide", name: "wide", role: role, engine: engine, parameters: .init(attack: 5, decay: 320, tune: -1, lowPass: 6_400, resonance: 0.42, drive: 0.16)),
                preset(id: "snare-noise-broken", name: "broken", role: role, engine: engine, parameters: .init(attack: 3, decay: 410, tune: 2, lowPass: 5_200, resonance: 0.58, drive: 0.30))
            ]
        case (.snare, .fm):
            return [
                preset(id: "snare-fm-hard", name: "hard", role: role, engine: engine, parameters: .init(attack: 2, decay: 220, tune: 6, lowPass: 9_200, resonance: 0.22, drive: 0.24)),
                preset(id: "snare-fm-clip", name: "clip", role: role, engine: engine, parameters: .init(attack: 1, decay: 180, tune: 8, lowPass: 11_000, resonance: 0.28, drive: 0.36))
            ]
        case (.snare, .sample):
            return [
                preset(id: "snare-sample-crack", name: "crack", role: role, engine: engine, parameters: .init(attack: 1, decay: 240, tune: 0, lowPass: 8_100, resonance: 0.18, drive: 0.14)),
                preset(id: "snare-sample-broken", name: "broken", role: role, engine: engine, parameters: .init(attack: 3, decay: 360, tune: -2, lowPass: 5_800, resonance: 0.36, drive: 0.30))
            ]
        case (.clap, .noise):
            return [
                preset(id: "clap-wide", name: "wide", role: role, engine: engine, parameters: .init(attack: 9, decay: 240, tune: 0, lowPass: 8_600, resonance: 0.40, drive: 0.18)),
                preset(id: "clap-hard", name: "hard", role: role, engine: engine, parameters: .init(attack: 4, decay: 180, tune: 2, lowPass: 10_400, resonance: 0.30, drive: 0.26))
            ]
        case (.clap, .sample):
            return [
                preset(id: "clap-sample-crisp", name: "crisp", role: role, engine: engine, parameters: .init(attack: 2, decay: 210, tune: -1, lowPass: 9_200, resonance: 0.24, drive: 0.12)),
                preset(id: "clap-sample-broken", name: "broken", role: role, engine: engine, parameters: .init(attack: 6, decay: 280, tune: 1, lowPass: 6_300, resonance: 0.42, drive: 0.24))
            ]
        case (.closedHat, .metal), (.openHat, .metal):
            let isOpen = role == .openHat
            return [
                preset(id: isOpen ? "hat-open" : "hat-tight", name: isOpen ? "open" : "tight", role: role, engine: engine, parameters: .init(attack: 1, decay: isOpen ? 520 : 120, tune: isOpen ? -2 : 1, lowPass: 10_800, resonance: 0.18, drive: 0.10)),
                preset(id: isOpen ? "hat-bright-open" : "hat-bright", name: "bright", role: role, engine: engine, parameters: .init(attack: 1, decay: isOpen ? 420 : 90, tune: 4, lowPass: 13_200, resonance: 0.22, drive: 0.12))
            ]
        case (.closedHat, .noise), (.openHat, .noise):
            let isOpen = role == .openHat
            return [
                preset(id: isOpen ? "hat-noise-open" : "hat-noise-tight", name: isOpen ? "open" : "tight", role: role, engine: engine, parameters: .init(attack: 2, decay: isOpen ? 480 : 80, tune: 0, lowPass: 9_600, resonance: 0.28, drive: 0.08)),
                preset(id: isOpen ? "hat-noise-broken" : "hat-noise-dry", name: isOpen ? "broken" : "dry", role: role, engine: engine, parameters: .init(attack: 3, decay: isOpen ? 560 : 70, tune: -3, lowPass: 7_400, resonance: 0.36, drive: 0.18))
            ]
        case (.closedHat, .sample), (.openHat, .sample):
            let isOpen = role == .openHat
            return [
                preset(id: isOpen ? "hat-sample-open" : "hat-sample-tight", name: isOpen ? "open" : "tight", role: role, engine: engine, parameters: .init(attack: 1, decay: isOpen ? 460 : 100, tune: 0, lowPass: 11_100, resonance: 0.16, drive: 0.06)),
                preset(id: isOpen ? "hat-sample-bright-open" : "hat-sample-bright-tight", name: "bright", role: role, engine: engine, parameters: .init(attack: 1, decay: isOpen ? 390 : 110, tune: 2, lowPass: 12_800, resonance: 0.20, drive: 0.10))
            ]
        default:
            return [
                preset(id: "\(role.rawValue)-\(engine.rawValue)-default", name: "default", role: role, engine: engine, parameters: .init(attack: 4, decay: 220, tune: 0, lowPass: 8_000, resonance: 0.2, drive: 0.1))
            ]
        }
    }

    static func preset(for role: VoiceRole, engine: VoiceEngine, id: String) -> VoicePresetDefinition? {
        presets(for: role, engine: engine).first(where: { $0.id == id })
    }

    static func defaultPreset(for role: VoiceRole, engine: VoiceEngine) -> VoicePresetDefinition {
        presets(for: role, engine: engine).first!
    }

    private static func makeVoice(
        role: VoiceRole,
        activeSteps: [Int],
        engine: VoiceEngine,
        presetID: String
    ) -> VoiceTrack {
        let preset = preset(for: role, engine: engine, id: presetID) ?? defaultPreset(for: role, engine: engine)
        return VoiceTrack(
            id: role.displayName,
            role: role,
            name: role.displayName,
            steps: (0..<16).map { activeSteps.contains($0 + 1) },
            engine: engine,
            presetID: preset.id,
            parameters: preset.parameters
        )
    }

    private static func preset(
        id: String,
        name: String,
        role: VoiceRole,
        engine: VoiceEngine,
        parameters: VoiceParameters
    ) -> VoicePresetDefinition {
        VoicePresetDefinition(
            id: id,
            name: name,
            role: role,
            engine: engine,
            parameters: parameters
        )
    }
}
