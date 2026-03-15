import Foundation
@testable import R1010

enum TestSupport {
    static func makeVoiceTrack(
        id: String = VoiceRole.kick.displayName,
        role: VoiceRole = .kick,
        steps: [Bool]? = nil,
        engine: VoiceEngine = .analog,
        presetID: String = "preset",
        parameters: VoiceParameters = .init(
            attack: 2,
            decay: 240,
            tune: 0,
            lowPass: 8_000,
            resonance: 0.2,
            drive: 0.1
        )
    ) -> VoiceTrack {
        VoiceTrack(
            id: id,
            role: role,
            name: id,
            steps: steps ?? Array(repeating: false, count: 16),
            engine: engine,
            presetID: presetID,
            parameters: parameters
        )
    }

    static func makePaths() -> SuperColliderPaths {
        SuperColliderPaths(
            appBundleURL: nil,
            sclangURL: URL(fileURLWithPath: "/tmp/sclang"),
            scsynthURL: URL(fileURLWithPath: "/tmp/scsynth"),
            sourceDescription: "test"
        )
    }
}
