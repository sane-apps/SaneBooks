import SwiftUI

/// In-app brand mark matching the dock icon (book + shield + keyhole).
public struct SaneBooksBrandMark: View {
    public var size: CGFloat = 64

    public init(size: CGFloat = 64) {
        self.size = size
    }

    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .fill(Color(red: 0.04, green: 0.09, blue: 0.16))
                .frame(width: size, height: size)

            // Open book
            HStack(spacing: size * 0.02) {
                bookPage(flipped: false)
                bookPage(flipped: true)
            }
            .frame(width: size * 0.62, height: size * 0.42)
            .offset(y: size * 0.04)

            // Shield
            SaneBooksShieldShape()
                .fill(Color.saneAccent)
                .frame(width: size * 0.28, height: size * 0.34)
                .overlay {
                    // Keyhole
                    VStack(spacing: 0) {
                        Circle()
                            .fill(Color.black.opacity(0.85))
                            .frame(width: size * 0.07, height: size * 0.07)
                        RoundedRectangle(cornerRadius: 1)
                            .fill(Color.black.opacity(0.85))
                            .frame(width: size * 0.035, height: size * 0.08)
                            .offset(y: -size * 0.01)
                    }
                    .offset(y: size * 0.02)
                }
        }
        .accessibilityLabel("SaneBooks")
    }

    private func bookPage(flipped: Bool) -> some View {
        RoundedRectangle(cornerRadius: size * 0.03, style: .continuous)
            .fill(Color.white)
            .rotationEffect(.degrees(flipped ? 8 : -8))
    }
}

private struct SaneBooksShieldShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        path.move(to: CGPoint(x: w * 0.5, y: 0))
        path.addLine(to: CGPoint(x: w, y: h * 0.18))
        path.addLine(to: CGPoint(x: w * 0.92, y: h * 0.58))
        path.addQuadCurve(
            to: CGPoint(x: w * 0.5, y: h),
            control: CGPoint(x: w * 0.88, y: h * 0.88)
        )
        path.addQuadCurve(
            to: CGPoint(x: w * 0.08, y: h * 0.58),
            control: CGPoint(x: w * 0.12, y: h * 0.88)
        )
        path.addLine(to: CGPoint(x: 0, y: h * 0.18))
        path.closeSubpath()
        return path
    }
}
