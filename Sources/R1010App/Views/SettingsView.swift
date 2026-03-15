import SwiftUI

struct SettingsView: View {
    @AppStorage("appearanceMode") private var appearanceModeRawValue = AppAppearance.system.rawValue

    private var appearance: AppAppearance {
        AppAppearance(rawValue: appearanceModeRawValue) ?? .system
    }

    var body: some View {
        VStack(spacing: 0) {
            Text("Settings")
                .font(.custom("IBM Plex Mono", size: 13))
                .foregroundStyle(R1010Theme.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(R1010Theme.panel)

            Rectangle()
                .fill(R1010Theme.divider)
                .frame(height: 1)

            VStack {
                HStack(spacing: 12) {
                    Text("color mode")
                        .font(.custom("IBM Plex Mono", size: 15))
                        .foregroundStyle(R1010Theme.textPrimary)

                    Spacer(minLength: 20)

                    Menu {
                        ForEach(AppAppearance.allCases) { mode in
                            Button(mode.rawValue) {
                                appearanceModeRawValue = mode.rawValue
                            }
                        }
                    } label: {
                        Text(appearance.rawValue)
                            .font(.custom("IBM Plex Mono", size: 14))
                            .foregroundStyle(R1010Theme.textPrimary)
                            .padding(.horizontal, 14)
                            .frame(height: 28)
                            .background(R1010Theme.buttonBackground, in: RoundedRectangle(cornerRadius: 6))
                    }
                    .menuStyle(.borderlessButton)
                }
                .padding(.horizontal, 16)
                .frame(height: 52)
                .background(R1010Theme.panel, in: RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(R1010Theme.divider, lineWidth: 1)
                }
            }
            .padding(.horizontal, 70)
            .padding(.top, 60)
            .padding(.bottom, 58)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(R1010Theme.canvas)
        }
        .frame(width: 460, height: 218)
        .background(R1010Theme.canvas)
    }
}
