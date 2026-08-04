import SaneBooksCore
import SwiftUI

struct SyncBanner: View {
    let cursor: SyncCursor?

    var body: some View {
        if let cursor {
            banner(icon: statusIcon(cursor.status), text: bannerText(cursor))
        } else {
            banner(icon: "clock", text: "Sync: Not started this session")
        }
    }

    private func banner(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .saneBooksFont(size: 14, weight: .semibold)
                .foregroundStyle(Color.saneBooksAccentSoft)
            Text(text)
                .saneBooksFont(size: 14, weight: .semibold)
                .foregroundStyle(.white)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.saneBooksAccent.opacity(0.35), lineWidth: 1)
        )
    }

    private func bannerText(_ cursor: SyncCursor) -> String {
        var parts = ["Sync: \(cursor.status.displayName)"]
        parts.append("block \(cursor.scannedThroughHeight.formatted())")
        parts.append("\(cursor.noteCount) notes")
        if cursor.isDemo {
            parts.append("demo")
        }
        return parts.joined(separator: " · ")
    }

    private func statusIcon(_ status: SyncStatus) -> String {
        switch status {
        case .caughtUp: "checkmark.circle.fill"
        case .scanning: "arrow.triangle.2.circlepath"
        case .stalled, .degraded: "exclamationmark.triangle.fill"
        case .capabilityBlocked: "xmark.octagon.fill"
        case .idle: "pause.circle.fill"
        }
    }
}
