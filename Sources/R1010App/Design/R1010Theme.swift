import AppKit
import SwiftUI

enum R1010Theme {
    static let canvas = dynamicColor(light: 0xF5F7F6, dark: 0x0F1011)
    static let panel = dynamicColor(light: 0xFFFFFF, dark: 0x151617)
    static let panelRaised = dynamicColor(light: 0xEDF2EF, dark: 0x121416)
    static let gridLine = dynamicColor(light: 0xD2D9D4, dark: 0x202423)
    static let divider = dynamicColor(light: 0xC8D0CB, dark: 0x1B201E)
    static let accent = dynamicColor(light: 0x0F9D72, dark: 0x37D6A4)
    static let textPrimary = dynamicColor(light: 0x151817, dark: 0xF3F5F4)
    static let textSecondary = dynamicColor(light: 0x5C6761, dark: 0x8E9994)
    static let textMuted = dynamicColor(light: 0x7A8680, dark: 0x68726D)
    static let buttonBackground = dynamicColor(light: 0xE5EBE7, dark: 0x1A1D1C)

    private static func dynamicColor(light: UInt, dark: UInt, alpha: Double = 1.0) -> Color {
        Color(
            nsColor: NSColor(name: nil) { appearance in
                let match = appearance.bestMatch(from: [.aqua, .darkAqua])
                return nsColor(hex: match == .darkAqua ? dark : light, alpha: alpha)
            }
        )
    }

    private static func nsColor(hex: UInt, alpha: Double = 1.0) -> NSColor {
        NSColor(
            calibratedRed: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            alpha: alpha
        )
    }
}

extension Color {
    init(hex: UInt, alpha: Double = 1.0) {
        self.init(
            nsColor: NSColor(
                calibratedRed: Double((hex >> 16) & 0xFF) / 255.0,
                green: Double((hex >> 8) & 0xFF) / 255.0,
                blue: Double(hex & 0xFF) / 255.0,
                alpha: alpha
            )
        )
    }
}
