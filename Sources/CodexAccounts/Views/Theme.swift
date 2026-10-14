import AppKit
import SwiftUI

enum Theme {
    static let canvas = Color(nsColor: .windowBackgroundColor)

    static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            nsColor(appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light)
        })
    }

    static func nsColor(_ hex: UInt32) -> NSColor {
        NSColor(srgbRed: CGFloat((hex >> 16) & 255) / 255,
                green: CGFloat((hex >> 8) & 255) / 255,
                blue: CGFloat(hex & 255) / 255, alpha: 1)
    }
}

extension AccountTint {
    var foreground: Color {
        switch self {
        case .sage: Theme.adaptive(light: 0x588268, dark: 0xA8D0B6)
        case .blue: Theme.adaptive(light: 0x587B9F, dark: 0xA6C5E8)
        case .lavender: Theme.adaptive(light: 0x8474A8, dark: 0xCFBFEF)
        case .peach: Theme.adaptive(light: 0xB28664, dark: 0xEAC5A4)
        case .graphite: Theme.adaptive(light: 0x707872, dark: 0xC4CDC5)
        }
    }
    var background: Color {
        switch self {
        case .sage: Theme.adaptive(light: 0xEAF1E5, dark: 0x31443A)
        case .blue: Theme.adaptive(light: 0xEDF2F7, dark: 0x2D3E51)
        case .lavender: Theme.adaptive(light: 0xF1EDF7, dark: 0x40364F)
        case .peach: Theme.adaptive(light: 0xF8EFE5, dark: 0x4B3D30)
        case .graphite: Theme.adaptive(light: 0xECEFEA, dark: 0x3B423D)
        }
    }
}

struct AccountAvatar: View {
    let account: Account
    var size: CGFloat = 46
    var body: some View {
        Image(systemName: account.symbol)
            .font(.system(size: size * 0.42, weight: .regular))
            .foregroundStyle(account.tint.foreground)
            .frame(width: size, height: size)
            .background(account.tint.background, in: RoundedRectangle(cornerRadius: size * 0.3))
            .accessibilityHidden(true)
    }
}

struct TinyLabel: View {
    let text: String
    var body: some View {
        Text(text).font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 5))
    }
}
