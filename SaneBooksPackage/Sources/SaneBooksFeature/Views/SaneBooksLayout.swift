import SwiftUI

/// Shared readable-column sizing so forms fill resized windows instead of
/// floating as a narrow centered card in dead space.
enum SaneBooksLayout {
    static let horizontalPadding: CGFloat = 28
    static let defaultMinContent: CGFloat = 560
    static let defaultMaxContent: CGFloat = 1000

    /// Prefer most of the usable width, clamped for readability on ultrawide.
    static func contentWidth(
        for containerWidth: CGFloat,
        min minWidth: CGFloat = defaultMinContent,
        max maxWidth: CGFloat = defaultMaxContent,
        fillFraction: CGFloat = 0.90
    ) -> CGFloat {
        let usable = max(0, containerWidth - (horizontalPadding * 2))
        let preferred = usable * fillFraction
        return min(maxWidth, max(minWidth, preferred))
    }
}

extension View {
    /// Caps width to a window-relative readable column and stretches to fill.
    func saneBooksReadableColumn(
        containerWidth: CGFloat,
        min minWidth: CGFloat = SaneBooksLayout.defaultMinContent,
        max maxWidth: CGFloat = SaneBooksLayout.defaultMaxContent,
        alignment: Alignment = .top
    ) -> some View {
        let width = SaneBooksLayout.contentWidth(
            for: containerWidth,
            min: minWidth,
            max: maxWidth
        )
        return frame(maxWidth: width, alignment: alignment)
            .frame(maxWidth: .infinity, alignment: alignment)
    }
}
