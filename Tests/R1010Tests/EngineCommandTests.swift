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

final class EngineScriptBuilderTests: XCTestCase {
    func testBootstrapScriptUsesPairBasedSwingTimingInSequencer() {
        let script = EngineScriptBuilder().bootstrapScript(
            configuration: EngineBootstrapConfiguration(scsynthPort: 57_140)
        )

        XCTAssertTrue(script.contains("var swingRatio = swing.clip(50, 75) / 100;"))
        XCTAssertTrue(script.contains("var pairDuration = stepDuration * 2;"))
        XCTAssertTrue(script.contains("var swungStepDuration = pairDuration * swingRatio;"))
        XCTAssertTrue(script.contains("var pairTrig = Impulse.kr((clampedTempo / 60) * 2);"))
        XCTAssertTrue(script.contains("var stepTrig = pairTrig + DelayN.kr(pairTrig, 1.0, swungStepDuration);"))
        XCTAssertFalse(script.contains("var stepTrig = Impulse.kr((clampedTempo / 60) * 4);"))
    }

    func testBootstrapScriptKeepsBootAndLiveSwingOnSameSequencerPath() {
        let script = EngineScriptBuilder().bootstrapScript(
            configuration: EngineBootstrapConfiguration(scsynthPort: 57_140)
        )

        XCTAssertTrue(script.contains("\\swing, (~r1010Swing ? 54).asFloat"))
        XCTAssertTrue(script.contains("~r1010CommandSetSwing = { |swing, sentinel|"))
        XCTAssertTrue(
            script.contains(
                "~r1010SequencerSynth.set(\\tempo, (~r1010Tempo ? 128).asFloat, \\swing, swing.asFloat);"
            )
        )
    }
}
