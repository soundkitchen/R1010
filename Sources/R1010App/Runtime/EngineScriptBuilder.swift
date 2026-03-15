import Foundation

struct EngineBootstrapConfiguration: Equatable {
    let scsynthPort: Int
}

struct EngineScriptBuilder {
    func bootstrapScript(configuration: EngineBootstrapConfiguration) -> String {
        """
        Routine.run({
        ~r1010Server = Server.remote(\\r1010, NetAddr("127.0.0.1", \(configuration.scsynthPort)));
        Server.default = ~r1010Server;
        s = ~r1010Server;

        ~r1010TransportState = \\stopped;
        ~r1010Tempo = 128;
        ~r1010Swing = 54;
        ~r1010VoiceOrder = [\\kick_1, \\snare_2, \\clap, \\closed_hat, \\open_hat];
        ~r1010VoicePrefixes = IdentityDictionary[
            \\kick_1 -> "kick",
            \\snare_2 -> "snare",
            \\clap -> "clap",
            \\closed_hat -> "closedHat",
            \\open_hat -> "openHat"
        ];
        ~r1010VoiceKinds = IdentityDictionary[
            \\kick_1 -> 0,
            \\snare_2 -> 1,
            \\clap -> 2,
            \\closed_hat -> 3,
            \\open_hat -> 4
        ];
        ~r1010EngineMaps = IdentityDictionary[
            \\kick_1 -> Dictionary["analog" -> 0, "fm" -> 1, "sample" -> 2],
            \\snare_2 -> Dictionary["analog" -> 0, "noise" -> 1, "fm" -> 2, "sample" -> 3],
            \\clap -> Dictionary["noise" -> 0, "sample" -> 1],
            \\closed_hat -> Dictionary["metal" -> 0, "noise" -> 1, "sample" -> 2],
            \\open_hat -> Dictionary["metal" -> 0, "noise" -> 1, "sample" -> 2]
        ];
        ~r1010VoiceState = IdentityDictionary.new;
        ~r1010StepState = IdentityDictionary.new;
        ~r1010StepBuffers = IdentityDictionary.new;
        ~r1010SequencerSynth = nil;
        ~r1010RootGroup = nil;

        ~r1010EnsureVoiceState = { |voiceID|
            var state = ~r1010VoiceState[voiceID];
            state.isNil.if({
                state = (
                    engine: "analog",
                    preset: "default",
                    attack: 2.0,
                    decay: 240.0,
                    tune: 0.0,
                    lowPass: 8000.0,
                    resonance: 0.2,
                    drive: 0.1
                );
                ~r1010VoiceState[voiceID] = state;
            });
            state
        };

        ~r1010EnsureStepData = { |voiceID|
            var steps = ~r1010StepState[voiceID];
            steps.isNil.if({
                steps = Array.fill(16, 0.0);
                ~r1010StepState[voiceID] = steps;
            });
            steps
        };

        ~r1010BuildSequencerArgs = {
            var args = List.newFrom([
                \\tempo, (~r1010Tempo ? 128).asFloat,
                \\swing, (~r1010Swing ? 54).asFloat
            ]);

            ~r1010VoiceOrder.do { |voiceID|
                var prefix = ~r1010VoicePrefixes[voiceID];
                var state = ~r1010EnsureVoiceState.(voiceID);
                var engineMap = ~r1010EngineMaps[voiceID] ? Dictionary.new;
                var buffer = ~r1010StepBuffers[voiceID];

                args.addAll([
                    (prefix ++ "Buf").asSymbol, buffer.bufnum,
                    (prefix ++ "Engine").asSymbol, (engineMap[state[\\engine] ? "analog"] ? 0).asFloat,
                    (prefix ++ "Attack").asSymbol, ((state[\\attack] ? 2.0).asFloat / 1000.0).clip(0.0005, 0.12),
                    (prefix ++ "Decay").asSymbol, ((state[\\decay] ? 240.0).asFloat / 1000.0).clip(0.02, 1.8),
                    (prefix ++ "Tune").asSymbol, (state[\\tune] ? 0.0).asFloat,
                    (prefix ++ "LowPass").asSymbol, (state[\\lowPass] ? 8000.0).asFloat,
                    (prefix ++ "Resonance").asSymbol, (state[\\resonance] ? 0.2).asFloat,
                    (prefix ++ "Drive").asSymbol, (state[\\drive] ? 0.1).asFloat
                ]);
            };

            args.asArray
        };

        ~r1010ApplyVoiceState = { |voiceID|
            var synth = ~r1010SequencerSynth;
            var prefix = ~r1010VoicePrefixes[voiceID];
            var state = ~r1010EnsureVoiceState.(voiceID);
            var engineMap = ~r1010EngineMaps[voiceID] ? Dictionary.new;

            (synth.notNil and: { prefix.notNil }).if({
                synth.set(
                    (prefix ++ "Engine").asSymbol, (engineMap[state[\\engine] ? "analog"] ? 0).asFloat,
                    (prefix ++ "Attack").asSymbol, ((state[\\attack] ? 2.0).asFloat / 1000.0).clip(0.0005, 0.12),
                    (prefix ++ "Decay").asSymbol, ((state[\\decay] ? 240.0).asFloat / 1000.0).clip(0.02, 1.8),
                    (prefix ++ "Tune").asSymbol, (state[\\tune] ? 0.0).asFloat,
                    (prefix ++ "LowPass").asSymbol, (state[\\lowPass] ? 8000.0).asFloat,
                    (prefix ++ "Resonance").asSymbol, (state[\\resonance] ? 0.2).asFloat,
                    (prefix ++ "Drive").asSymbol, (state[\\drive] ? 0.1).asFloat
                );
            });
        };

        ~r1010PreviewVoice = { |voiceID|
            var state = ~r1010EnsureVoiceState.(voiceID);
            var engineMap = ~r1010EngineMaps[voiceID] ? Dictionary.new;
            var target = ~r1010RootGroup ? ~r1010Server.defaultGroup;

            Synth.tail(
                target,
                \\r1010PreviewVoice,
                [
                    \\voiceKind, (~r1010VoiceKinds[voiceID] ? 0).asFloat,
                    \\engine, (engineMap[state[\\engine] ? "analog"] ? 0).asFloat,
                    \\attack, ((state[\\attack] ? 2.0).asFloat / 1000.0).clip(0.0005, 0.12),
                    \\decay, ((state[\\decay] ? 240.0).asFloat / 1000.0).clip(0.02, 1.8),
                    \\tune, (state[\\tune] ? 0.0).asFloat,
                    \\lowPass, (state[\\lowPass] ? 8000.0).asFloat,
                    \\resonance, (state[\\resonance] ? 0.2).asFloat,
                    \\drive, (state[\\drive] ? 0.1).asFloat
                ]
            );
        };

        ~r1010StopTransport = {
            ~r1010SequencerSynth.notNil.if({
                ~r1010SequencerSynth.free;
                ~r1010SequencerSynth = nil;
            });
            ~r1010TransportState = \\stopped;
        };

        ~r1010StartTransport = {
            (~r1010StopTransport ? { }).value;
            ~r1010SequencerSynth = Synth.tail(
                ~r1010RootGroup,
                \\r1010Sequencer,
                ~r1010BuildSequencerArgs.()
            );
            ~r1010TransportState = \\playing;
        };

        ~r1010RunServerCommand = { |body, sentinel|
            Routine.run({
                body.value;
                ~r1010Server.notNil.if({ ~r1010Server.sync; });
                sentinel.postln;
            });
        };

        ~r1010CommandPlay = { |sentinel|
            ~r1010RunServerCommand.({ (~r1010StartTransport ? { }).value; }, sentinel);
        };

        ~r1010CommandStop = { |sentinel|
            ~r1010RunServerCommand.({ (~r1010StopTransport ? { }).value; }, sentinel);
        };

        ~r1010CommandSetTempo = { |bpm, sentinel|
            ~r1010RunServerCommand.({
                ~r1010Tempo = bpm;
                ~r1010SequencerSynth.notNil.if({
                    ~r1010SequencerSynth.set(\\tempo, bpm.asFloat, \\swing, (~r1010Swing ? 54).asFloat);
                });
            }, sentinel);
        };

        ~r1010CommandSetSwing = { |swing, sentinel|
            ~r1010RunServerCommand.({
                ~r1010Swing = swing;
                ~r1010SequencerSynth.notNil.if({
                    ~r1010SequencerSynth.set(\\tempo, (~r1010Tempo ? 128).asFloat, \\swing, swing.asFloat);
                });
            }, sentinel);
        };

        ~r1010CommandSetSteps = { |voiceID, steps, sentinel|
            ~r1010RunServerCommand.({
                ~r1010StepState = ~r1010StepState ? IdentityDictionary.new;
                ~r1010StepState[voiceID] = steps;
                (~r1010StepBuffers.notNil and: { ~r1010StepBuffers[voiceID].notNil }).if({
                    ~r1010StepBuffers[voiceID].setn(0, steps);
                });
            }, sentinel);
        };

        ~r1010CommandSetVoiceEngine = { |voiceID, engine, sentinel|
            ~r1010RunServerCommand.({
                ~r1010VoiceState = ~r1010VoiceState ? IdentityDictionary.new;
                ~r1010VoiceState[voiceID] = (~r1010VoiceState[voiceID] ? ());
                ~r1010VoiceState[voiceID].put(\\engine, engine);
                (~r1010ApplyVoiceState ? { }).value(voiceID);
            }, sentinel);
        };

        ~r1010CommandSetVoicePreset = { |voiceID, presetID, sentinel|
            ~r1010RunServerCommand.({
                ~r1010VoiceState = ~r1010VoiceState ? IdentityDictionary.new;
                ~r1010VoiceState[voiceID] = (~r1010VoiceState[voiceID] ? ());
                ~r1010VoiceState[voiceID].put(\\preset, presetID);
            }, sentinel);
        };

        ~r1010CommandSetVoiceParams = { |voiceID, attack, decay, tune, lowPass, resonance, drive, sentinel|
            ~r1010RunServerCommand.({
                ~r1010VoiceState = ~r1010VoiceState ? IdentityDictionary.new;
                ~r1010VoiceState[voiceID] = (~r1010VoiceState[voiceID] ? ()).putAll((
                    attack: attack,
                    decay: decay,
                    tune: tune,
                    lowPass: lowPass,
                    resonance: resonance,
                    drive: drive
                ));
                (~r1010ApplyVoiceState ? { }).value(voiceID);
            }, sentinel);
        };

        ~r1010CommandPreviewVoice = { |voiceID, sentinel|
            ~r1010RunServerCommand.({
                (~r1010PreviewVoice ? { }).value(voiceID);
            }, sentinel);
        };

        ~r1010Server.notify = true;
        ~r1010Server.initTree;
        ~r1010Server.sync;
        ~r1010RootGroup = Group.head(~r1010Server.defaultGroup);
        ~r1010Server.sync;

            SynthDef(\\r1010PreviewVoice, {
                |out = 0, voiceKind = 0, engine = 0, attack = 0.002, decay = 0.24, tune = 0, lowPass = 8000, resonance = 0.2, drive = 0.1|
                var shape = { |signal, cutoff, reso, gain|
                    var rq = (1.02 - reso.clip(0.10, 1.0)).clip(0.06, 0.95);
                    var filtered = RLPF.ar(signal, cutoff.clip(240, 18000), rq);
                    tanh(filtered * (1 + (gain.clip(0, 1) * 8)))
                };
                var ampEnv = EnvGen.kr(Env.perc(attack.clip(0.0005, 0.12), decay.clip(0.02, 1.8), 1, -4), doneAction: 2);
                var shortEnv = EnvGen.kr(Env.perc(0.0008, (decay * 0.35).clip(0.02, 0.7), 1, -5));
                var clapBurst = Mix.fill(4, { |index|
                    EnvGen.kr(
                        Env(
                            [0, 1, 0],
                            [0.001, (decay * (0.20 + (index * 0.08))).clip(0.02, 0.7)],
                            [-4, -4]
                        ),
                        timeScale: 1,
                        levelScale: 1,
                        levelBias: 0,
                        gate: 1
                    ) * (1.0 - (index * 0.14))
                });
                var kick = shape.(
                    SelectX.ar(engine.clip(0, 2), [
                        SinOsc.ar((34 + tune + (shortEnv * 28)).midicps),
                        SinOsc.ar((30 + tune).midicps + (shortEnv * 130)),
                        LFTri.ar((40 + tune + (shortEnv * 16)).midicps)
                    ]) * ampEnv + (HPF.ar(WhiteNoise.ar(0.08), 2800) * shortEnv),
                    lowPass,
                    resonance,
                    drive
                ) * 0.95;
                var snare = shape.(
                    SelectX.ar(engine.clip(0, 3), [
                        (SinOsc.ar((50 + tune).midicps) + (SinOsc.ar((57 + tune).midicps) * 0.5)) * ampEnv + (BPF.ar(WhiteNoise.ar(0.8), (2600 + (tune * 90)).clip(900, 7200), 0.7) * shortEnv),
                        HPF.ar(WhiteNoise.ar(0.9), 1800) * ampEnv,
                        SinOsc.ar((70 + tune).midicps + (shortEnv * 300), 0, ampEnv) + (BPF.ar(WhiteNoise.ar(0.55), 2400, 0.8) * shortEnv),
                        (HPF.ar(WhiteNoise.ar(0.9), 1500) * ampEnv) + (LFTri.ar((64 + tune).midicps) * shortEnv * 0.35)
                    ]),
                    lowPass,
                    resonance,
                    drive
                ) * 0.78;
                var clap = shape.(
                    SelectX.ar(engine.clip(0, 1), [
                        HPF.ar(WhiteNoise.ar(0.85), 1200) * clapBurst,
                        HPF.ar(PinkNoise.ar(0.75), 900) * clapBurst
                    ]),
                    lowPass,
                    resonance,
                    drive
                ) * 0.62;
                var closedHat = shape.(
                    SelectX.ar(engine.clip(0, 2), [
                        Mix([
                            LFPulse.ar((94 + tune).midicps * 1.0, 0, 0.5, 0.05),
                            LFPulse.ar((94 + tune).midicps * 1.31, 0, 0.5, 0.05),
                            LFPulse.ar((94 + tune).midicps * 1.79, 0, 0.5, 0.04)
                        ]) * ampEnv,
                        HPF.ar(WhiteNoise.ar(0.6), 6500) * ampEnv,
                        HPF.ar(PinkNoise.ar(0.5), 7400) * ampEnv
                    ]),
                    lowPass,
                    resonance,
                    drive
                ) * 0.45;
                var openHat = shape.(
                    SelectX.ar(engine.clip(0, 2), [
                        Mix([
                            LFPulse.ar((92 + tune).midicps * 1.0, 0, 0.5, 0.05),
                            LFPulse.ar((92 + tune).midicps * 1.29, 0, 0.5, 0.05),
                            LFPulse.ar((92 + tune).midicps * 1.73, 0, 0.5, 0.04)
                        ]) * ampEnv,
                        HPF.ar(WhiteNoise.ar(0.55), 5800) * ampEnv,
                        HPF.ar(PinkNoise.ar(0.48), 6800) * ampEnv
                    ]),
                    lowPass,
                    resonance,
                    drive
                ) * 0.38;
                var signal = SelectX.ar(voiceKind.clip(0, 4), [kick, snare, clap, closedHat, openHat]);

                Out.ar(out, Limiter.ar((signal * 0.9) ! 2, 0.95));
            }).send(~r1010Server);

            SynthDef(\\r1010Sequencer, {
                |out = 0, tempo = 128, swing = 54,
                kickBuf = 0, snareBuf = 0, clapBuf = 0, closedHatBuf = 0, openHatBuf = 0,
                kickEngine = 0, snareEngine = 0, clapEngine = 0, closedHatEngine = 0, openHatEngine = 0,
                kickAttack = 0.002, kickDecay = 0.42, kickTune = 0, kickLowPass = 7800, kickResonance = 0.22, kickDrive = 0.14,
                snareAttack = 0.003, snareDecay = 0.26, snareTune = 1, snareLowPass = 8800, snareResonance = 0.32, snareDrive = 0.18,
                clapAttack = 0.009, clapDecay = 0.24, clapTune = 0, clapLowPass = 8600, clapResonance = 0.40, clapDrive = 0.18,
                closedHatAttack = 0.001, closedHatDecay = 0.12, closedHatTune = 1, closedHatLowPass = 10800, closedHatResonance = 0.18, closedHatDrive = 0.10,
                openHatAttack = 0.001, openHatDecay = 0.52, openHatTune = -2, openHatLowPass = 10800, openHatResonance = 0.18, openHatDrive = 0.10|
                var clampedTempo = tempo.clip(30, 220);
                var swingRatio = swing.clip(50, 75) / 100;
                var stepDuration = 60 / clampedTempo / 4;
                var pairDuration = stepDuration * 2;
                var swungStepDuration = pairDuration * swingRatio;
                // Keep each 16th-note pair at a constant length while delaying the second step.
                // `1.0` seconds safely covers the current 30 BPM / 75% swing maximum delay.
                var pairTrig = Impulse.kr((clampedTempo / 60) * 2);
                var stepTrig = pairTrig + DelayN.kr(pairTrig, 1.0, swungStepDuration);
                var stepIndex = Stepper.kr(stepTrig, 0, 0, 15, 1, 15);
                var readGate = { |buffer|
                    BufRd.kr(1, buffer, stepIndex, interpolation: 0, loop: 1) > 0.5
                };
                var shape = { |signal, lowPass, resonance, drive|
                    var rq = (1.05 - resonance.clip(0.10, 1.0)).clip(0.05, 0.95);
                    var filtered = RLPF.ar(signal, lowPass.clip(240, 18000), rq);
                    tanh(filtered * (1 + (drive.clip(0, 1) * 7)))
                };
                var kickTrig = stepTrig * readGate.(kickBuf);
                var snareTrig = stepTrig * readGate.(snareBuf);
                var clapTrig = stepTrig * readGate.(clapBuf);
                var closedHatTrig = stepTrig * readGate.(closedHatBuf);
                var openHatTrig = stepTrig * readGate.(openHatBuf);

                var kickEnv = Decay2.kr(kickTrig, kickAttack.clip(0.0005, 0.12), kickDecay.clip(0.02, 1.8));
                var kickPitchEnv = Decay2.kr(kickTrig, 0.001, (kickDecay * 0.35).clip(0.03, 0.9));
                var kickBody = SelectX.ar(kickEngine.clip(0, 2), [
                    SinOsc.ar((34 + kickTune + (kickPitchEnv * 32)).midicps),
                    SinOsc.ar((30 + kickTune).midicps + (kickPitchEnv * 120)),
                    LFTri.ar((38 + kickTune + (kickPitchEnv * 14)).midicps)
                ]) * kickEnv * 0.95;
                var kickClick = HPF.ar(WhiteNoise.ar(0.14), 3200) * Decay2.kr(kickTrig, 0.0008, 0.012);
                var kick = shape.(kickBody + kickClick, kickLowPass, kickResonance, kickDrive);

                var snareBodyEnv = Decay2.kr(snareTrig, snareAttack.clip(0.0005, 0.08), (snareDecay * 0.55).clip(0.03, 1.1));
                var snareNoiseEnv = Decay2.kr(snareTrig, 0.001, snareDecay.clip(0.05, 1.4));
                var snareAnalog = (
                    SinOsc.ar((50 + snareTune).midicps) +
                    SinOsc.ar((57 + snareTune).midicps, 0, 0.6)
                ) * snareBodyEnv;
                var snareNoise = BPF.ar(WhiteNoise.ar(0.9), (2400 + (snareTune * 90)).clip(800, 7000), 0.7) * snareNoiseEnv;
                var snareFM = SinOsc.ar((72 + snareTune).midicps + (snareNoiseEnv * 280), 0, snareBodyEnv);
                var snareSample = (HPF.ar(WhiteNoise.ar(0.8), 1800) * snareNoiseEnv) + (LFTri.ar((64 + snareTune).midicps) * snareBodyEnv * 0.35);
                var snare = shape.(SelectX.ar(snareEngine.clip(0, 3), [
                    snareAnalog + (snareNoise * 0.65),
                    snareNoise,
                    snareFM + (snareNoise * 0.45),
                    snareSample
                ]), snareLowPass, snareResonance, snareDrive) * 0.82;

                var clapPulse = Trig1.kr(clapTrig, 0.001);
                var clapBurst = Mix.fill(4, { |index|
                    Decay2.kr(
                        TDelay.kr(clapPulse, index * 0.013),
                        clapAttack.clip(0.001, 0.05),
                        (clapDecay * (0.20 + (index * 0.06))).clip(0.03, 1.2)
                    )
                });
                var clapNoise = HPF.ar(WhiteNoise.ar(0.8), 1200) * clapBurst;
                var clapTone = BPF.ar(clapNoise, (2200 + (clapTune * 100)).clip(900, 7000), 0.5);
                var clapSample = HPF.ar(PinkNoise.ar(0.75), 900) * clapBurst;
                var clap = shape.(SelectX.ar(clapEngine.clip(0, 1), [
                    clapTone,
                    clapSample
                ]), clapLowPass, clapResonance, clapDrive) * 0.62;

                var closedHatEnv = Decay2.kr(closedHatTrig, closedHatAttack.clip(0.0005, 0.04), closedHatDecay.clip(0.02, 1.2));
                var closedHatMetal = Mix([
                    LFPulse.ar((94 + closedHatTune).midicps * 1.0, 0, 0.5, 0.05),
                    LFPulse.ar((94 + closedHatTune).midicps * 1.31, 0, 0.5, 0.05),
                    LFPulse.ar((94 + closedHatTune).midicps * 1.79, 0, 0.5, 0.04),
                    LFPulse.ar((94 + closedHatTune).midicps * 2.43, 0, 0.5, 0.04),
                    LFPulse.ar((94 + closedHatTune).midicps * 3.17, 0, 0.5, 0.03)
                ]) * closedHatEnv;
                var closedHatNoise = HPF.ar(WhiteNoise.ar(0.55), 6500) * closedHatEnv;
                var closedHatSample = HPF.ar(PinkNoise.ar(0.45), 7600) * closedHatEnv;
                var closedHat = shape.(SelectX.ar(closedHatEngine.clip(0, 2), [
                    closedHatMetal,
                    closedHatNoise,
                    closedHatSample
                ]), closedHatLowPass, closedHatResonance, closedHatDrive) * 0.40;

                var openHatEnv = Decay2.kr(openHatTrig, openHatAttack.clip(0.0005, 0.04), openHatDecay.clip(0.06, 1.8));
                var openHatMetal = Mix([
                    LFPulse.ar((92 + openHatTune).midicps * 1.0, 0, 0.5, 0.05),
                    LFPulse.ar((92 + openHatTune).midicps * 1.29, 0, 0.5, 0.05),
                    LFPulse.ar((92 + openHatTune).midicps * 1.73, 0, 0.5, 0.04),
                    LFPulse.ar((92 + openHatTune).midicps * 2.41, 0, 0.5, 0.04),
                    LFPulse.ar((92 + openHatTune).midicps * 3.05, 0, 0.5, 0.03)
                ]) * openHatEnv;
                var openHatNoise = HPF.ar(WhiteNoise.ar(0.5), 5800) * openHatEnv;
                var openHatSample = HPF.ar(PinkNoise.ar(0.45), 6900) * openHatEnv;
                var openHat = shape.(SelectX.ar(openHatEngine.clip(0, 2), [
                    openHatMetal,
                    openHatNoise,
                    openHatSample
                ]), openHatLowPass, openHatResonance, openHatDrive) * 0.34;

                Out.ar(out, Limiter.ar(((kick + snare + clap + closedHat + openHat) * 0.72) ! 2, 0.95));
            }).send(~r1010Server);

        ~r1010VoiceOrder.do { |voiceID|
            ~r1010EnsureVoiceState.(voiceID);
            ~r1010EnsureStepData.(voiceID);
            ~r1010StepBuffers[voiceID] = Buffer.alloc(~r1010Server, 16, 1);
        };

        ~r1010Server.sync;
        ~r1010VoiceOrder.do { |voiceID|
            ~r1010StepBuffers[voiceID].setn(0, ~r1010StepState[voiceID]);
        };
        ~r1010Server.sync;
        "R1010_BOOTSTRAP_READY".postln;
        });
        """
    }

    func writeBootstrapScript(
        configuration: EngineBootstrapConfiguration,
        to directoryURL: URL
    ) throws -> URL {
        let fileURL = directoryURL.appendingPathComponent("bootstrap.scd")
        try bootstrapScript(configuration: configuration)
            .write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }
}
