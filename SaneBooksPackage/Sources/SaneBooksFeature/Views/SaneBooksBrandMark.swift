import SwiftUI

/// In-app brand mark matching the dock icon: full-bleed closed ledger.
/// Fills the mark (Apple-readable at dock size); gold title band = Zcash-adjacent.
public struct SaneBooksBrandMark: View {
    public var size: CGFloat = 64

    public init(size: CGFloat = 64) {
        self.size = size
    }

    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            SaneBooksTheme.inkElevated,
                            SaneBooksTheme.ink,
                            SaneBooksTheme.inkMid
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
                .overlay {
                    RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                        .stroke(Color.saneBooksAccent.opacity(0.35), lineWidth: max(1, size * 0.02))
                }

            // Full-bleed ledger — ~94% of the tile
            ZStack(alignment: .leading) {
                // Page stack edge
                RoundedRectangle(cornerRadius: size * 0.05, style: .continuous)
                    .fill(SaneBooksTheme.pageIvory.opacity(0.85))
                    .frame(width: size * 0.90, height: size * 0.90)
                    .offset(x: size * 0.03)

                RoundedRectangle(cornerRadius: size * 0.05, style: .continuous)
                    .fill(SaneBooksTheme.pageIvory)
                    .frame(width: size * 0.90, height: size * 0.90)

                // Spine
                RoundedRectangle(cornerRadius: 0)
                    .fill(SaneBooksTheme.goldDeep)
                    .frame(width: size * 0.12, height: size * 0.90)

                VStack(alignment: .leading, spacing: size * 0.045) {
                    RoundedRectangle(cornerRadius: size * 0.02, style: .continuous)
                        .fill(Color.saneBooksAccent)
                        .frame(height: size * 0.12)
                        .padding(.leading, size * 0.16)
                        .padding(.trailing, size * 0.08)
                        .padding(.top, size * 0.12)

                    ForEach(0 ..< 5, id: \.self) { i in
                        Capsule()
                            .fill(SaneBooksTheme.ink.opacity(0.22 - Double(i) * 0.02))
                            .frame(height: max(1.5, size * 0.024))
                            .padding(.leading, size * 0.18)
                            .padding(.trailing, size * 0.10 + CGFloat(i) * size * 0.02)
                    }
                    Spacer(minLength: 0)
                }
                .frame(width: size * 0.90, height: size * 0.90)
            }
            .frame(width: size * 0.94, height: size * 0.94)
        }
        .accessibilityLabel("SaneBooks")
    }
}
