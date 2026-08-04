import SwiftUI

/// Zcash-familiar private-ledger palette for SaneBooks only.
/// Does not change global SaneUI teal (`#0DA3C7`) used by other SaneApps.
public enum SaneBooksTheme: Sendable {
    /// ZEC Gold — primary accent ([zcash.design](https://zcash.design/zcash-design-guide.html) `#F4B728`).
    public static let gold = Color(red: 244.0 / 255.0, green: 183.0 / 255.0, blue: 40.0 / 255.0)
    /// Soft highlight (`#FDC63E` — live z.cash CSS).
    public static let goldSoft = Color(red: 253.0 / 255.0, green: 198.0 / 255.0, blue: 62.0 / 255.0)
    /// Deep gold for pressed / light-on-gold text (`#C8880A`).
    public static let goldDeep = Color(red: 200.0 / 255.0, green: 136.0 / 255.0, blue: 10.0 / 255.0)
    /// Warm near-black ink (privacy ledger base).
    public static let ink = Color(red: 12.0 / 255.0, green: 11.0 / 255.0, blue: 9.0 / 255.0)
    public static let inkMid = Color(red: 22.0 / 255.0, green: 20.0 / 255.0, blue: 16.0 / 255.0)
    public static let inkElevated = Color(red: 32.0 / 255.0, green: 28.0 / 255.0, blue: 20.0 / 255.0)
    /// Warm gold-brown for glass panel tint (replaces teal panelTint).
    public static let panelTint = Color(red: 0.42, green: 0.32, blue: 0.10)
    /// Page / book mark off-white.
    public static let pageIvory = Color(red: 0.96, green: 0.94, blue: 0.88)
}

public extension Color {
    static let saneBooksAccent = SaneBooksTheme.gold
    static let saneBooksAccentSoft = SaneBooksTheme.goldSoft
    static let saneBooksAccentDeep = SaneBooksTheme.goldDeep
}

/// Warm ink + gold ambient mesh — Zcash-adjacent, not Sane teal ocean.
public struct SaneBooksInkBackground: View {
    public init() {}

    public var body: some View {
        ZStack {
            SaneBooksTheme.ink
            RadialGradient(
                colors: [
                    SaneBooksTheme.gold.opacity(0.14),
                    SaneBooksTheme.goldDeep.opacity(0.06),
                    Color.clear
                ],
                center: .topTrailing,
                startRadius: 20,
                endRadius: 520
            )
            RadialGradient(
                colors: [
                    SaneBooksTheme.inkElevated.opacity(0.85),
                    Color.clear
                ],
                center: .bottomLeading,
                startRadius: 10,
                endRadius: 480
            )
            LinearGradient(
                colors: [
                    SaneBooksTheme.inkMid.opacity(0.55),
                    Color.clear,
                    SaneBooksTheme.gold.opacity(0.04)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }
}

public extension View {
    /// Apply SaneBooks ZEC-gold brand chrome to this subtree.
    func saneBooksBrand() -> some View {
        saneBrandAccent(SaneBooksTheme.gold, soft: SaneBooksTheme.goldSoft)
    }
}

public extension Notification.Name {
    /// Posted to open the SwiftUI Settings scene (Dock menu, TopNav fallback).
    static let saneBooksOpenSettings = Notification.Name("saneBooksOpenSettings")
}
