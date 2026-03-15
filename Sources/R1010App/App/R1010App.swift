import SwiftUI

@main
struct R1010App: App {
    @AppStorage("appearanceMode") private var appearanceModeRawValue = AppAppearance.system.rawValue
    @StateObject private var appModel = AppModel()
    @StateObject private var sequencerStore = SequencerStateStore()

    private var appearance: AppAppearance {
        AppAppearance(rawValue: appearanceModeRawValue) ?? .system
    }

    var body: some Scene {
        WindowGroup {
            RootContentView()
                .environmentObject(appModel)
                .environmentObject(sequencerStore)
                .preferredColorScheme(appearance.colorScheme)
                .frame(minWidth: 1200, minHeight: 820)
                .task {
                    await appModel.bootstrapIfNeeded(initialState: sequencerStore)
                }
                .task(id: appearanceModeRawValue) {
                    appearance.applyToApplication()
                }
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                    appModel.shutdown()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1280, height: 860)
        .commands {
            TransportCommands(appModel: appModel, sequencerStore: sequencerStore)
        }

        Settings {
            SettingsView()
                .preferredColorScheme(appearance.colorScheme)
                .task(id: appearanceModeRawValue) {
                    appearance.applyToApplication()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 460, height: 218)
    }
}

private struct TransportCommands: Commands {
    @ObservedObject var appModel: AppModel
    @ObservedObject var sequencerStore: SequencerStateStore

    var body: some Commands {
        CommandMenu("Transport") {
            Button(sequencerStore.isPlaying ? "Stop" : "Play") {
                Task {
                    await appModel.togglePlayback(for: sequencerStore)
                }
            }
            .keyboardShortcut(.space, modifiers: [])
        }
    }
}
