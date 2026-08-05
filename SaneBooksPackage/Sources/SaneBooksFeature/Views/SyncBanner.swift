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
        HStack(spacing: 10) {
            Image(systemName: icon)
                .saneBooksFont(size: 13, weight: .semibold)
                .foregroundStyle(Color.saneBooksAccentSoft)
            Text(text)
                .saneBooksFont(size: 13, weight: .semibold)
                .foregroundStyle(.white)
                .lineLimit(1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            Capsule(style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(Color.saneBooksAccent.opacity(0.35), lineWidth: 1)
        )
        .fixedSize(horizontal: true, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
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
