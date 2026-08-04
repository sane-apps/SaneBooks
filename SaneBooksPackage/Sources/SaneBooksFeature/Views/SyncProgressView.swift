import SwiftUI

public struct SyncProgressView: View {
    @Bindable var model: AppModel

    public var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Syncing vault…")
                .font(.title2.bold())
                .foregroundStyle(.white)

            Text("Scanning shielded history")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)

            if let cursor = model.cursor {
                accentProgressBar(fraction: cursor.progressFraction)

                HStack(spacing: 8) {
                    Text("\(Int((cursor.progressFraction * 100).rounded()))%")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.saneBooksAccent)
                    Text("Block \(cursor.scannedThroughHeight.formatted())")
                    if let tip = cursor.chainTipHeight {
                        Text("· tip \(tip.formatted())")
                    }
                    if let eta = cursor.etaSeconds {
                        Text("· ~\(max(1, Int(eta / 60))) min left")
                    }
                    Text("· \(cursor.status.displayName)")
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)

                if cursor.isDemo {
                    demoBanner
                }
            } else {
                accentProgressBar(fraction: 0.08)
                Text("Starting sync…")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
            }

            Text("You can leave this window open. Tagging unlocks when notes appear.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)

            Spacer()

            ActionButton("Cancel sync", style: .secondary) {
                model.cancelSync()
            }
            .frame(width: 160)
        }
        .padding(32)
    }

    private func accentProgressBar(fraction: Double) -> some View {
        let clamped = min(max(fraction, 0), 1)
        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color.white.opacity(0.12))
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color.saneBooksAccent)
                    .frame(width: max(8, geo.size.width * clamped))
            }
        }
        .frame(height: 12)
        .accessibilityLabel("Sync progress")
        .accessibilityValue("\(Int((clamped * 100).rounded())) percent")
    }

    private var demoBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(Color.saneBooksAccent)
            Text("Demo ledger — not live chain data")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.saneBooksAccent.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
