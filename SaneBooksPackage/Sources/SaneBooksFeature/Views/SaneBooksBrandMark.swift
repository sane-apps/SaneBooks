import SwiftUI

/// In-app brand mark matching the dock icon: closed ledger + horizontal gold band.
/// Book-first (accountant). No shield/keyhole/open-eye geometry.
public struct SaneBooksBrandMark: View {
    public var size: CGFloat = 64

    public init(size: CGFloat = 64) {
        self.size = size
    }

    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .fill(SaneBooksTheme.inkElevated)
                .frame(width: size, height: size)

            // Closed ledger cover
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: size * 0.05, style: .continuous)
                    .fill(SaneBooksTheme.pageIvory)
                    .frame(width: size * 0.56, height: size * 0.60)

                // Spine
                RoundedRectangle(cornerRadius: 0)
                    .fill(SaneBooksTheme.ink.opacity(0.55))
                    .frame(width: size * 0.06, height: size * 0.60)

                // Title plate + quiet ledger lines (upper gold band, not a pupil)
                VStack(alignment: .leading, spacing: size * 0.055) {
                    RoundedRectangle(cornerRadius: size * 0.015, style: .continuous)
                        .fill(Color.saneBooksAccent)
                        .frame(height: size * 0.065)
                        .padding(.leading, size * 0.1)
                        .padding(.trailing, size * 0.07)
                        .padding(.top, size * 0.08)

                    Spacer(minLength: 0)

                    ForEach(0 ..< 3, id: \.self) { _ in
                        Capsule()
                            .fill(SaneBooksTheme.ink.opacity(0.14))
                            .frame(height: max(1.2, size * 0.014))
                            .padding(.leading, size * 0.12)
                            .padding(.trailing, size * 0.1)
                    }
                    .padding(.bottom, size * 0.08)
                }
                .frame(width: size * 0.56, height: size * 0.60)
            }
            .frame(width: size * 0.56, height: size * 0.60)
        }
        .accessibilityLabel("SaneBooks")
    }
}
