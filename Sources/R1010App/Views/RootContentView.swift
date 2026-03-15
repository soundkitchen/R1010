import SwiftUI

struct RootContentView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var sequencer: SequencerStateStore

    var body: some View {
        ZStack {
            R1010Theme.canvas.ignoresSafeArea()

            VStack(spacing: 24) {
                header
                bodyContent
            }
            .padding(32)
        }
        .overlay {
            if appModel.isBooting {
                BootOverlayView(message: appModel.bootMessage)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("R-1010")
                    .font(.custom("IBM Plex Mono", size: 28))
                    .foregroundStyle(R1010Theme.textPrimary)
                Text("SuperCollider rhythm machine")
                    .font(.custom("IBM Plex Mono", size: 11))
                    .foregroundStyle(R1010Theme.textSecondary)
                    .tracking(0.6)
            }

            Spacer()

            Text(appModel.statusLabel(isPlaying: sequencer.isPlaying))
                .font(.custom("IBM Plex Mono", size: 12))
                .foregroundStyle(R1010Theme.accent)
                .padding(.top, 6)

            Spacer()

            TransportBarView()
        }
    }

    private var bodyContent: some View {
        HStack(spacing: 32) {
            VoicesPanel()
                .frame(width: 180)

            SequencerPanel()
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            VoiceEditorPanel()
                .frame(width: 220)
        }
        .frame(maxHeight: .infinity)
    }
}

private struct TransportBarView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var sequencer: SequencerStateStore

    var body: some View {
        HStack(spacing: 6) {
            TransportChip(title: sequencer.isPlaying ? "stop" : "play", isSelected: sequencer.isPlaying, action: {
                Task {
                    await appModel.togglePlayback(for: sequencer)
                }
            })
            TransportValueChip(
                title: "bpm",
                value: Binding(
                    get: { sequencer.tempo },
                    set: { newValue in
                        sequencer.setTempo(newValue)
                    }
                ),
                range: 60...180,
                rangeLabel: "60-180"
            ) { newValue in
                Task {
                    await appModel.syncTempo(newValue)
                }
            }
            TransportValueChip(
                title: "swing",
                value: Binding(
                    get: { sequencer.swing },
                    set: { newValue in
                        sequencer.setSwing(newValue)
                    }
                ),
                range: 50...75,
                rangeLabel: "50-75"
            ) { newValue in
                Task {
                    await appModel.syncSwing(newValue)
                }
            }
        }
        .padding(6)
        .background(R1010Theme.panelRaised, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(R1010Theme.divider, lineWidth: 1)
        )
    }
}

private struct VoicesPanel: View {
    @EnvironmentObject private var sequencer: SequencerStateStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("voices")
                .font(.custom("IBM Plex Mono", size: 18))
                .foregroundStyle(R1010Theme.textPrimary)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(sequencer.tracks) { track in
                    Button {
                        sequencer.selectVoice(track.id)
                    } label: {
                        Text(track.name)
                            .font(.custom("IBM Plex Mono", size: 12))
                            .foregroundStyle(track.id == sequencer.selectedVoiceID ? R1010Theme.textPrimary : R1010Theme.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer()
        }
        .padding(16)
        .panelStyle()
    }
}

private struct SequencerPanel: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var sequencer: SequencerStateStore

    private let trackColumnWidth: CGFloat = 96

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Menu {
                    ForEach(sequencer.availablePatterns, id: \.self) { pattern in
                        Button(pattern) {
                            sequencer.selectPattern(pattern)
                            Task {
                                await appModel.syncSelectedPatternPage(from: sequencer)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(sequencer.selectedPattern)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .font(.custom("IBM Plex Mono", size: 12))
                    .foregroundStyle(R1010Theme.textPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(R1010Theme.buttonBackground, in: RoundedRectangle(cornerRadius: 6))
                }
                .menuStyle(.borderlessButton)

                Text("16 step")
                    .font(.custom("IBM Plex Mono", size: 11))
                    .foregroundStyle(R1010Theme.textMuted)

                Spacer()

                HStack(spacing: 8) {
                    Text("page")
                        .font(.custom("IBM Plex Mono", size: 11))
                        .foregroundStyle(R1010Theme.textMuted)

                    ForEach(1...4, id: \.self) { page in
                        Button {
                            sequencer.selectPage(page)
                            Task {
                                await appModel.syncSelectedPatternPage(from: sequencer)
                            }
                        } label: {
                            Text("\(page)")
                                .font(.custom("IBM Plex Mono", size: 11))
                                .foregroundStyle(page == sequencer.selectedPage ? R1010Theme.textPrimary : R1010Theme.textSecondary)
                                .frame(width: 18)
                        }
                        .buttonStyle(.plain)
                    }

                    Button {
                        _ = sequencer.clearCurrentPage()
                        Task {
                            await appModel.syncSelectedPatternPage(from: sequencer)
                        }
                    } label: {
                        Text("clear")
                            .font(.custom("IBM Plex Mono", size: 10))
                            .foregroundStyle(R1010Theme.textSecondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(R1010Theme.buttonBackground, in: RoundedRectangle(cornerRadius: 5))
                    }
                    .buttonStyle(.plain)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Text("trk")
                        .foregroundStyle(R1010Theme.textSecondary)
                        .frame(width: trackColumnWidth, alignment: .leading)

                    ForEach(1...16, id: \.self) { step in
                        Text(String(format: "%02d", step))
                            .foregroundStyle(R1010Theme.textMuted)
                            .frame(minWidth: 18, maxWidth: .infinity)
                    }
                }
                .font(.custom("IBM Plex Mono", size: 10))

                ForEach(sequencer.tracks) { track in
                    HStack(spacing: 10) {
                        Text(track.name)
                            .font(.custom("IBM Plex Mono", size: 11))
                            .foregroundStyle(R1010Theme.textSecondary)
                            .frame(width: trackColumnWidth, alignment: .leading)

                        ForEach(Array(track.steps.enumerated()), id: \.offset) { item in
                            StepCell(isActive: item.element) {
                                guard let updatedTrack = sequencer.toggleStep(trackID: track.id, stepIndex: item.offset) else {
                                    return
                                }

                                Task {
                                    await appModel.syncSteps(for: updatedTrack)
                                    if updatedTrack.steps[item.offset] {
                                        await appModel.previewVoice(updatedTrack)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 4)

            Spacer(minLength: 0)
        }
        .padding(16)
        .panelStyle()
    }
}

private struct VoiceEditorPanel: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var sequencer: SequencerStateStore

    @State private var isEngineSelectorOpen = false
    @State private var isPresetSelectorOpen = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let voice = sequencer.selectedVoice {
                VStack(alignment: .leading, spacing: 6) {
                    Text("selected_voice")
                        .font(.custom("IBM Plex Mono", size: 11))
                        .foregroundStyle(R1010Theme.textMuted)
                    Text(voice.name)
                        .font(.custom("IBM Plex Mono", size: 16))
                        .foregroundStyle(R1010Theme.textPrimary)
                }

                VoiceSelectorRow(
                    title: "engine",
                    value: voice.engine.title,
                    isPresented: $isEngineSelectorOpen
                ) {
                    SelectionPopover(
                        title: "engine",
                        options: voice.allowedEngines.map { .init(id: $0.id, title: $0.title) },
                        selectedID: voice.engine.id
                    ) { selectedID in
                        guard let engine = voice.allowedEngines.first(where: { $0.id == selectedID }),
                              let updatedVoice = sequencer.selectEngine(engine, for: voice.id) else {
                            return
                        }

                        isEngineSelectorOpen = false

                        Task {
                            await appModel.syncVoiceDefinition(updatedVoice)
                            await appModel.previewVoice(updatedVoice)
                        }
                    }
                }

                VoiceSelectorRow(
                    title: "preset",
                    value: voice.presetName,
                    isPresented: $isPresetSelectorOpen
                ) {
                    SelectionPopover(
                        title: "preset",
                        options: voice.presets.map { .init(id: $0.id, title: $0.name) },
                        selectedID: voice.presetID
                    ) { selectedID in
                        guard let updatedVoice = sequencer.selectPreset(selectedID, for: voice.id) else {
                            return
                        }

                        isPresetSelectorOpen = false

                        Task {
                            await appModel.syncVoiceDefinition(updatedVoice)
                            await appModel.previewVoice(updatedVoice)
                        }
                    }
                }

                Button {
                    Task {
                        await appModel.previewVoice(voice)
                    }
                } label: {
                    Text("tap")
                        .font(.custom("IBM Plex Mono", size: 11))
                        .foregroundStyle(R1010Theme.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(R1010Theme.buttonBackground, in: RoundedRectangle(cornerRadius: 6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(R1010Theme.divider, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)

                ForEach(VoiceParameterKey.allCases) { key in
                    ParameterControlRow(
                        title: key.title,
                        value: voice.parameters[key],
                        range: key.range,
                        valueLabel: key.formatted(voice.parameters[key])
                    ) { newValue in
                        guard let updatedVoice = sequencer.updateParameter(key, value: newValue, for: voice.id) else {
                            return
                        }

                        Task {
                            await appModel.syncVoiceDefinition(updatedVoice)
                        }
                    }
                }

                Spacer()
            } else {
                Text("No voice selected")
                    .font(.custom("IBM Plex Mono", size: 12))
                    .foregroundStyle(R1010Theme.textSecondary)
            }
        }
        .padding(16)
        .panelStyle()
    }
}

private struct TransportChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.custom("IBM Plex Mono", size: 11))
                .foregroundStyle(isSelected ? R1010Theme.textPrimary : R1010Theme.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(isSelected ? R1010Theme.buttonBackground : Color.clear, in: RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain)
    }
}

private struct TransportValueChip: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Double>
    let rangeLabel: String
    let onChange: (Int) -> Void

    @State private var isPresented = false
    @State private var draftValue = ""
    @FocusState private var isInputFocused: Bool

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            HStack(spacing: 4) {
                Text(title)
                    .foregroundStyle(R1010Theme.textMuted)
                Text("\(value)")
                    .foregroundStyle(R1010Theme.textPrimary)
            }
            .font(.custom("IBM Plex Mono", size: 11))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(R1010Theme.buttonBackground, in: RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isPresented, attachmentAnchor: .rect(.bounds), arrowEdge: .top) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text(title)
                        .font(.custom("IBM Plex Mono", size: 14))
                        .foregroundStyle(R1010Theme.textPrimary)

                    TextField(
                        "",
                        text: $draftValue
                    )
                        .textFieldStyle(.plain)
                        .font(.custom("IBM Plex Mono", size: 12))
                        .foregroundStyle(R1010Theme.textPrimary)
                        .frame(width: 72)
                        .multilineTextAlignment(.trailing)
                        .focused($isInputFocused)
                        .onSubmit {
                            commitDraftValue()
                        }

                    Spacer()

                    Text(rangeLabel)
                        .font(.custom("IBM Plex Mono", size: 10))
                        .foregroundStyle(R1010Theme.textMuted)
                }

                Slider(
                    value: Binding(
                        get: { Double(value) },
                        set: { newValue in
                            let rounded = Int(newValue.rounded())
                            value = rounded
                            draftValue = "\(rounded)"
                            onChange(rounded)
                        }
                    ),
                    in: range,
                    step: 1
                )
                .tint(R1010Theme.accent)
            }
            .padding(12)
            .frame(width: 220)
            .background(R1010Theme.panelRaised)
            .onAppear {
                draftValue = "\(value)"
                DispatchQueue.main.async {
                    isInputFocused = true
                }
            }
        }
        .onChange(of: isPresented) { _, presented in
            if presented {
                draftValue = "\(value)"
                return
            }

            commitDraftValue()
        }
        .onChange(of: isInputFocused) { _, focused in
            if !focused {
                commitDraftValue()
            }
        }
    }

    private func commitDraftValue() {
        let trimmed = draftValue.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            draftValue = "\(value)"
            return
        }

        guard let parsed = Int(trimmed) else {
            draftValue = "\(value)"
            return
        }

        let clamped = min(max(parsed, Int(range.lowerBound)), Int(range.upperBound))
        draftValue = "\(clamped)"

        guard clamped != value else {
            return
        }

        value = clamped
        onChange(clamped)
    }
}

private struct VoiceSelectorRow<PopoverContent: View>: View {
    let title: String
    let value: String
    @Binding var isPresented: Bool
    @ViewBuilder let popoverContent: () -> PopoverContent

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.custom("IBM Plex Mono", size: 11))
                .foregroundStyle(R1010Theme.textMuted)

            Button {
                isPresented.toggle()
            } label: {
                HStack(spacing: 8) {
                    Text(value)
                        .foregroundStyle(R1010Theme.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(R1010Theme.textSecondary)
                }
                .font(.custom("IBM Plex Mono", size: 12))
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(R1010Theme.buttonBackground, in: RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(R1010Theme.divider, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .popover(isPresented: $isPresented, attachmentAnchor: .rect(.bounds), arrowEdge: .trailing) {
                popoverContent()
            }
        }
    }
}

private struct SelectionPopover: View {
    struct Option: Identifiable {
        let id: String
        let title: String
    }

    let title: String
    let options: [Option]
    let selectedID: String
    let onSelect: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.custom("IBM Plex Mono", size: 14))
                .foregroundStyle(R1010Theme.textPrimary)

            VStack(alignment: .leading, spacing: 4) {
                ForEach(options) { option in
                    Button {
                        onSelect(option.id)
                    } label: {
                        HStack {
                            Text(option.title)
                                .foregroundStyle(option.id == selectedID ? R1010Theme.textPrimary : R1010Theme.textSecondary)
                            Spacer()
                            if option.id == selectedID {
                                Text("current")
                                    .foregroundStyle(R1010Theme.accent)
                            }
                        }
                        .font(.custom("IBM Plex Mono", size: 11))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(
                            option.id == selectedID ? R1010Theme.buttonBackground : Color.clear,
                            in: RoundedRectangle(cornerRadius: 5)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(12)
        .frame(width: 188)
        .background(R1010Theme.panelRaised)
    }
}

private struct ParameterControlRow: View {
    let title: String
    let value: Double
    let range: ClosedRange<Double>
    let valueLabel: String
    let onChange: (Double) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.custom("IBM Plex Mono", size: 11))
                    .foregroundStyle(R1010Theme.textMuted)
                Spacer()
                Text(valueLabel)
                    .font(.custom("IBM Plex Mono", size: 10))
                    .foregroundStyle(R1010Theme.textSecondary)
            }

            Slider(
                value: Binding(
                    get: { value },
                    set: { onChange($0) }
                ),
                in: range
            )
            .tint(R1010Theme.accent)
        }
    }
}

private struct StepCell: View {
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            RoundedRectangle(cornerRadius: 2)
                .fill(isActive ? R1010Theme.accent : R1010Theme.buttonBackground.opacity(0.55))
                .overlay(
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(isActive ? R1010Theme.accent : R1010Theme.gridLine, lineWidth: 1)
                )
                .shadow(color: isActive ? R1010Theme.accent.opacity(0.35) : .clear, radius: 3, y: 1)
                .frame(minWidth: 18, maxWidth: .infinity, minHeight: 18, maxHeight: 18)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct BootOverlayView: View {
    let message: String

    var body: some View {
        ZStack {
            R1010Theme.canvas.opacity(0.9).ignoresSafeArea()

            VStack(spacing: 12) {
                ProgressView()
                    .controlSize(.small)
                    .tint(R1010Theme.accent)

                Text(message)
                    .font(.custom("IBM Plex Mono", size: 12))
                    .foregroundStyle(R1010Theme.textPrimary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .background(R1010Theme.panelRaised, in: RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(R1010Theme.divider, lineWidth: 1)
            )
        }
    }
}

private extension View {
    func panelStyle() -> some View {
        self
            .background(R1010Theme.panel, in: RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(R1010Theme.divider, lineWidth: 1)
            )
    }
}
