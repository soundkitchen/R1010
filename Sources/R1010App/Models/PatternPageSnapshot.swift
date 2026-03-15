import Foundation

struct VoiceStepSnapshot: Equatable {
    let voiceID: String
    let steps: [Bool]
}

struct PatternPageSnapshot: Equatable {
    let voices: [VoiceStepSnapshot]

    init(tracks: [VoiceTrack]) {
        voices = tracks.map { track in
            VoiceStepSnapshot(voiceID: track.id, steps: track.steps)
        }
    }
}
