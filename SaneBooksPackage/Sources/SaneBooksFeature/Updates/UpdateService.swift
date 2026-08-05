import AppKit
import os.log
import SaneUI
import Sparkle
import SwiftUI

private let updateLogger = Logger(subsystem: "com.saneapps.SaneBooks", category: "Update")

enum SaneBooksSparkleCheckFrequency: String, CaseIterable, Identifiable {
    case daily
    case weekly

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .daily: "Daily"
        case .weekly: "Weekly"
        }
    }

    var interval: TimeInterval {
        switch self {
        case .daily: 60 * 60 * 24
        case .weekly: 60 * 60 * 24 * 7
        }
    }

    static func resolve(updateCheckInterval: TimeInterval) -> Self {
        let threshold = (Self.daily.interval + Self.weekly.interval) / 2
        return updateCheckInterval >= threshold ? .weekly : .daily
    }

    static func normalizedInterval(from updateCheckInterval: TimeInterval) -> TimeInterval {
        resolve(updateCheckInterval: updateCheckInterval).interval
    }
}

/// Sparkle wrapper for the direct-download channel (zecbooks.app appcast).
@MainActor
public final class UpdateService: NSObject, ObservableObject, SPUUpdaterDelegate {
    public static let shared = UpdateService()

    public nonisolated static let releaseBundleIdentifier = "com.saneapps.SaneBooks"
    public nonisolated static let manualDownloadURL = "https://zecbooks.app/download"

    private var updaterController: SPUStandardUpdaterController?
    private let updateChannelEnabled: Bool
    private var isPresentingManualFallback = false

    override public init() {
        updateChannelEnabled = Self.supportsSparkleUpdates(
            bundleIdentifier: Bundle.main.bundleIdentifier
        )
        super.init()

        guard updateChannelEnabled else {
            updateLogger.info("Sparkle disabled for non-release bundle")
            return
        }

        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: self,
            userDriverDelegate: nil
        )
        if let updater = updaterController?.updater {
            updater.automaticallyDownloadsUpdates = true
            updater.updateCheckInterval = SaneBooksSparkleCheckFrequency.normalizedInterval(
                from: updater.updateCheckInterval
            )
        }
        updateLogger.info("Sparkle updater initialized")

        if let profiling = Bundle.main.object(forInfoDictionaryKey: "SUEnableSystemProfiling") as? Bool,
           profiling == true {
            updateLogger.fault("SUEnableSystemProfiling is enabled — disable it")
        }
    }

    var eligibility: SaneUpdateEligibility {
        SaneUpdateEligibility.resolve(
            bundleIdentifier: Bundle.main.bundleIdentifier,
            releaseBundleIdentifier: Self.releaseBundleIdentifier,
            bundlePath: Bundle.main.bundlePath
        )
    }

    var isUpdateChannelEnabled: Bool {
        updateChannelEnabled
    }

    var automaticallyChecksForUpdates: Bool {
        get { updateChannelEnabled && (updaterController?.updater.automaticallyChecksForUpdates ?? false) }
        set {
            guard updateChannelEnabled else { return }
            updaterController?.updater.automaticallyChecksForUpdates = newValue
        }
    }

    var updateCheckFrequency: SaneBooksSparkleCheckFrequency {
        get {
            let interval = updaterController?.updater.updateCheckInterval
                ?? SaneBooksSparkleCheckFrequency.daily.interval
            return SaneBooksSparkleCheckFrequency.resolve(updateCheckInterval: interval)
        }
        set {
            guard updateChannelEnabled else { return }
            updaterController?.updater.updateCheckInterval = newValue.interval
        }
    }

    public func checkForUpdates() {
        guard updateChannelEnabled else {
            NSSound.beep()
            return
        }
        let currentEligibility = eligibility
        guard currentEligibility.canUseInAppUpdates else {
            let status = currentEligibility.userFacingStatus
            updateLogger.info("Update check blocked: \(status, privacy: .public)")
            NSSound.beep()
            return
        }
        updateLogger.info("User triggered check for updates")
        updaterController?.checkForUpdates(nil)
    }

    public nonisolated static func supportsSparkleUpdates(bundleIdentifier: String?) -> Bool {
        bundleIdentifier == releaseBundleIdentifier
    }

    public nonisolated func updater(
        _: SPUUpdater,
        didFinishUpdateCycleFor updateCheck: SPUUpdateCheck,
        error: (any Error)?
    ) {
        guard let nsError = error as NSError? else { return }
        Task { @MainActor in
            self.handleFinishedUpdateCycle(updateCheck: updateCheck, error: nsError)
        }
    }

    private func handleFinishedUpdateCycle(updateCheck: SPUUpdateCheck, error: NSError) {
        if error.domain == SUSparkleErrorDomain, error.code == Int(SparkleErrorCode.noUpdate.rawValue) {
            updateLogger.info("Sparkle: no update available")
            return
        }

        updateLogger.error(
            "Sparkle cycle failed: domain=\(error.domain, privacy: .public) code=\(error.code)"
        )

        guard updateCheck == .updates, error.domain == SUSparkleErrorDomain else { return }
        switch SparkleErrorCode(rawValue: Int32(error.code)) {
        case .none, .noUpdate?, .installationCanceled?, .installationAuthorizeLater?:
            return
        default:
            presentManualDownloadFallback()
        }
    }

    private func presentManualDownloadFallback() {
        guard !isPresentingManualFallback else { return }
        guard let url = URL(string: Self.manualDownloadURL) else { return }
        isPresentingManualFallback = true
        defer { isPresentingManualFallback = false }

        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Update couldn’t finish automatically"
        alert.informativeText =
            "ZecBooks couldn’t complete the automatic update on this Mac. Open the download page and install the latest version manually?"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open Download Page")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(url)
        }
    }

    private enum SparkleErrorCode: Int32 {
        case appcastParse = 1000
        case noUpdate = 1001
        case runningFromDiskImage = 1003
        case temporaryDirectory = 2000
        case download = 2001
        case unarchiving = 3000
        case validation = 3002
        case missingInstallerTool = 4003
        case relaunch = 4004
        case installation = 4005
        case installationCanceled = 4007
        case installationAuthorizeLater = 4008
        case agentInvalidation = 4010
        case installationWriteNoPermission = 4012
    }
}

struct SaneBooksSparkleSettingsSection: View {
    @ObservedObject private var updates = UpdateService.shared
    @State private var isChecking = false

    var body: some View {
        let eligibility = updates.eligibility
        CompactSection("Updates", icon: "arrow.triangle.2.circlepath", iconColor: SaneSettingsIconSemantic.sync.color) {
            if !eligibility.canUseInAppUpdates {
                CompactRow("Status") {
                    Text(eligibility.userFacingStatus)
                        .saneBooksFont(size: SaneTypography.bodySize, weight: .medium)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.trailing)
                        .fixedSize(horizontal: false, vertical: true)
                }
                CompactDivider()
            }

            CompactToggle(
                label: "Check for updates automatically",
                isOn: Binding(
                    get: { updates.automaticallyChecksForUpdates },
                    set: { updates.automaticallyChecksForUpdates = $0 }
                )
            )
            .disabled(!eligibility.canUseInAppUpdates)

            CompactDivider()

            CompactRow("Check frequency") {
                Picker(
                    "Check frequency",
                    selection: Binding(
                        get: { updates.updateCheckFrequency },
                        set: { updates.updateCheckFrequency = $0 }
                    )
                ) {
                    ForEach(SaneBooksSparkleCheckFrequency.allCases) { frequency in
                        Text(frequency.title).tag(frequency)
                    }
                }
                .labelsHidden()
                .frame(width: 120)
                .disabled(!eligibility.canUseInAppUpdates || !updates.automaticallyChecksForUpdates)
            }

            CompactDivider()

            CompactRow("Actions") {
                Button(isChecking ? "Checking…" : "Check Now") {
                    isChecking = true
                    updates.checkForUpdates()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        isChecking = false
                    }
                }
                .buttonStyle(SaneActionButtonStyle())
                .disabled(!eligibility.canUseInAppUpdates || isChecking)
            }
        }
    }
}
