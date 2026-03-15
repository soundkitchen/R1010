import XCTest
@testable import R1010

final class EngineCommandTests: XCTestCase {
    func testSetPatternPageSerializesAtomicSnapshotCommand() {
        let kick = TestSupport.makeVoiceTrack(
            id: VoiceRole.kick.displayName,
            role: .kick,
            steps: [
                true, false, true, false,
                false, false, false, false,
                false, false, false, false,
                false, false, false, false
            ]
        )
        let snare = TestSupport.makeVoiceTrack(
            id: VoiceRole.snare.displayName,
            role: .snare,
            steps: [
                false, false, false, true,
                false, false, false, false,
                false, false, false, false,
                false, false, false, false
            ]
        )

        let snapshot = PatternPageSnapshot(tracks: [kick, snare])
        let script = EngineCommand.setPatternPage(snapshot).script(sentinel: "TOKEN")

        XCTAssertEqual(
            script,
            "~r1010CommandSetPatternPage.value([[\\kick_1, [1.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]], [\\snare_2, [0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]]], \"TOKEN\");"
        )
    }
}
