# TODO

This file tracks correctness issues that should be fixed before the current runtime behavior is considered stable.

Last updated: 2026-03-16

## P1. Make `swing` affect sequencer timing

- Priority: P1
- Status: Completed
- Area: SuperCollider sequencer timing

### Resolution

- Fixed in `Sources/R1010App/Runtime/EngineScriptBuilder.swift`.
- The sequencer now applies swing inside the SuperCollider timing path while preserving average tempo across each 16th-note pair.
- Merged via PR #1 (`94b77f0` on `main`).

### Problem

`swing` is exposed as a public transport parameter and is already wired through the app and runtime command path, but the actual sequencer timing remains straight. Users can change swing from the UI, and boot-time sync also sends swing, yet playback timing does not change.

### Why this is a bug

- `EngineCommand.setSwing` exists and is sent from Swift.
- `EngineScriptBuilder` passes `\\swing` into `~r1010BuildSequencerArgs`.
- `~r1010CommandSetSwing` stores the value and updates the running sequencer synth.
- `SynthDef(\\r1010Sequencer)` accepts a `swing` argument.
- However, the timing logic still uses:
  - `stepTrig = Impulse.kr((tempo.clip(30, 220) / 60) * 4)`
  - `stepIndex = Stepper.kr(stepTrig, ...)`
- The `swing` argument is never used in `stepTrig`, `stepIndex`, or any other part of the step scheduling path.

### User-visible symptom

- Changing swing from the UI appears to succeed but has no audible effect.
- Booting with a non-default swing value also produces straight playback.
- The app exposes a transport parameter that is currently non-functional.

### Reproduction

1. Boot the runtime normally.
2. Program a pattern with dense 16th notes, for example closed hat on every step.
3. Start playback.
4. Change swing across a wide range.
5. Observe that the rhythmic spacing remains straight.

### Implementation requirements

- Apply swing inside the sequencer timing calculation, not only in parameter plumbing.
- Preserve the average tempo across a two-step pair. Swing should redistribute timing, not globally speed up or slow down the bar.
- Ensure live `setSwing` updates affect the currently running transport without requiring restart.
- Ensure boot-time swing and live swing use the same timing logic.

### Acceptance criteria

- A dense 16th-note pattern audibly changes feel when swing changes.
- Every second 16th note is delayed or advanced according to the chosen swing model.
- BPM remains stable over multiple bars.
- Live swing changes and boot-time swing produce the same timing behavior.

### Related files

- `Sources/R1010App/Runtime/EngineCommand.swift`
- `Sources/R1010App/Runtime/EngineScriptBuilder.swift`

## P2. Apply live page/pattern resync atomically

- Priority: P2
- Status: Completed
- Area: Live pattern/page switching while transport is running

### Resolution

- Fixed in `Sources/R1010App/App/AppModel.swift`, `Sources/R1010App/Views/RootContentView.swift`, `Sources/R1010App/Runtime/EngineCommand.swift`, and `Sources/R1010App/Runtime/EngineScriptBuilder.swift`.
- `pattern` / `page` / `clear` now send a single `setPatternPage` command instead of a full project resync.
- The runtime now writes the incoming page snapshot into an inactive step-buffer bank and swaps the sequencer synth's buffer references only after the full snapshot is staged.
- Added regression tests for the atomic command path and command serialization in `Tests/R1010Tests/`.

### Problem

When the user switches pattern, switches page, or clears the current page during playback, the app resends the current project state as a series of separate runtime commands. The runtime applies each command immediately. If the transport crosses a 16th-note boundary while this resync is still in progress, one step can be rendered from a mixed old/new state.

### Where it happens

- `RootContentView` calls `appModel.syncProjectState(from: sequencer)` after:
  - pattern selection
  - page selection
  - `clearCurrentPage()`
- `AppModel.syncProjectState(from:)` sends commands in sequence:
  - `setTempo`
  - `setSwing`
  - for each track: `setSteps`
  - for each track: `setVoiceEngine`
  - for each track: `setVoicePreset`
  - for each track: `setVoiceParams`

For the current 5-voice layout, one full resync is at least 22 sequential commands.

### Why this causes mixed playback

- `SclangBridge.send` waits for each command to complete before sending the next one.
- `~r1010RunServerCommand` executes the command body, performs `server.sync`, then returns.
- This means commands are serialized, but not applied as one atomic snapshot.
- `setSteps` updates one voice buffer at a time.
- The running sequencer reads `kickBuf`, `snareBuf`, `clapBuf`, `closedHatBuf`, and `openHatBuf` independently on each `stepTrig`.

As a result, there is a real intermediate state where some voice buffers already contain the new page or pattern and others still contain the old one.

### Concrete failure scenario

1. Playback is running on page 1.
2. The user switches to page 2.
3. The runtime has already applied `setSteps` for `kick`, but not yet for `snare`, `clap`, or hats.
4. The next 16th-note boundary arrives before the rest of the commands finish.
5. That step is rendered as a hybrid snapshot:
   - `kick` reads page 2
   - other voices still read page 1

`clear` has the same failure mode: some voices may already be cleared while others still play one old step.

### Important nuance

This is not a Swift threading bug. The problem is that the runtime state is observable between commands while transport continues to advance.

### Implementation requirements

- Make page/pattern/clear resync atomic from the runtime point of view.
- Prefer a single runtime command that applies the full snapshot for all voices in one server-side closure.
- Alternatively, stage updates into inactive state and swap them on a step boundary.
- Avoid resending voice engine/preset/parameter data on page-only changes unless those values actually changed. Unnecessary commands widen the partial-update window.
- Keep live playback running; the fix should not require stopping transport around every page switch.

### Acceptance criteria

- No mixed old/new step occurs when switching page during playback.
- No mixed old/new step occurs when switching pattern during playback.
- No partial clear occurs when pressing `clear` during playback.
- Rapid repeated page changes still apply cleanly without one-tick hybrid states.

### Related files

- `Sources/R1010App/App/AppModel.swift`
- `Sources/R1010App/Views/RootContentView.swift`
- `Sources/R1010App/Runtime/SclangBridge.swift`
- `Sources/R1010App/Runtime/EngineScriptBuilder.swift`

## P3. Preserve play intent issued before runtime becomes ready

- Priority: P3
- Status: Completed
- Area: Boot-time transport state reconciliation

### Resolution

- Fixed in `Sources/R1010App/App/AppModel.swift` and `Tests/R1010Tests/AppModelTests.swift`.
- `bootstrapIfNeeded(initialState:)` now reconciles the final desired transport state from `SequencerStateStore.isPlaying` before exposing the runtime as ready.
- Added regression tests covering `Play during boot` and `Play -> Stop during boot`.

### Problem

Playback can be toggled before the runtime reaches `.ready`, for example from keyboard or menu commands while the boot overlay is still visible. The UI state flips immediately, but the corresponding runtime sync is dropped because the runtime is not ready yet. The desired play state is not replayed after boot completes.

### Why this is a bug

- `AppModel.togglePlayback(for:)` computes `shouldPlay` and immediately calls `stateStore.togglePlayback()`.
- If `shouldPlay` is true, it then calls `syncProjectState(from:)`.
- It always calls `syncTransport(isPlaying:)` afterward.
- `send(_:)` returns early unless `launchState` is `.ready`.
- `bootstrapIfNeeded(initialState:)` sends boot-time project data before `launchState = .ready(session)`.
- After the runtime becomes ready, there is no reconciliation step that replays the pending transport intent from `stateStore.isPlaying`.

### User-visible symptom

1. Launch the app.
2. While the boot overlay is still shown, press Space or trigger Play from the menu.
3. The UI flips to a playing state.
4. Boot completes.
5. Actual transport remains stopped because the earlier runtime commands were discarded.

The result is a UI/runtime mismatch: the app looks like it is playing, but the sequencer is not running.

### Implementation requirements

- Treat play/stop requests during boot as desired state that must be reconciled once the runtime is ready.
- Do not silently discard the transport intent.
- After initial project sync succeeds and the runtime transitions to ready, send the final desired transport state.
- Handle multiple toggles during boot correctly. Example: Play then Stop during boot must end in stopped state.
- Ensure UI status does not claim runtime playback that has not actually started, unless the UI explicitly distinguishes a queued intent from confirmed playback.

### Acceptance criteria

- Pressing Play during boot starts actual playback once runtime initialization finishes.
- Pressing Play and then Stop during boot leaves transport stopped after boot.
- UI play state and runtime transport state do not diverge across the boot transition.

### Related files

- `Sources/R1010App/App/AppModel.swift`
- `Sources/R1010App/App/R1010App.swift`
- `Sources/R1010App/Views/RootContentView.swift`
