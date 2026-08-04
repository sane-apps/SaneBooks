import SwiftUI

/// Product type scale — adult density, not juvenile chunk.
/// Body floor matches SaneUI / global AGENTS (13pt bright).
public enum SaneBooksType {
    public static let body: CGFloat = 13
    public static let label: CGFloat = 13
    public static let title: CGFloat = 16
    public static let display: CGFloat = 22
    public static let hero: CGFloat = 28
}

public enum SaneBooksTextSize: String, CaseIterable, Identifiable, Sendable {
    case standard
    case large
    case extraLarge

    public var id: String {
        rawValue
    }

    public var displayName: String {
        switch self {
        case .standard: "Standard"
        case .large: "Large"
        case .extraLarge: "Extra Large"
        }
    }

    public var scale: CGFloat {
        switch self {
        case .standard: 1
        case .large: 1.16
        case .extraLarge: 1.35
        }
    }
}

struct SaneBooksTextScaleKey: EnvironmentKey {
    static let defaultValue: CGFloat = 1
}

extension EnvironmentValues {
    var saneBooksTextScale: CGFloat {
        get { self[SaneBooksTextScaleKey.self] }
        set { self[SaneBooksTextScaleKey.self] = newValue }
    }
}

private struct SaneBooksFontModifier: ViewModifier {
    @Environment(\.saneBooksTextScale) private var textScale

    let size: CGFloat
    let weight: Font.Weight
    let design: Font.Design

    func body(content: Content) -> some View {
        // Body copy should grow generously, while headings grow more gently.
        // Scaling every size equally made 28 pt headings overwhelm the screen.
        let requestedScale = max(1, min(textScale, SaneBooksTextSize.extraLarge.scale))
        let headingCap: CGFloat = if size >= SaneBooksType.hero {
            1.20
        } else if size >= SaneBooksType.display {
            1.28
        } else {
            requestedScale
        }

        content.font(.system(
            size: size * min(requestedScale, headingCap),
            weight: weight,
            design: design
        ))
    }
}

public extension View {
    /// Uses the app's persisted text-size preference. SwiftUI Dynamic Type is
    /// intentionally not used because Apple documents that it does not change
    /// text size on macOS.
    func saneBooksFont(
        size: CGFloat,
        weight: Font.Weight = .regular,
        design: Font.Design = .default
    ) -> some View {
        modifier(SaneBooksFontModifier(size: size, weight: weight, design: design))
    }

    func saneBooksTextScale(_ scale: CGFloat) -> some View {
        environment(\.saneBooksTextScale, scale)
    }
}
