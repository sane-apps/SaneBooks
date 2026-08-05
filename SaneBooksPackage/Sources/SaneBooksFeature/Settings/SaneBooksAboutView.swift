import SaneUI
import SwiftUI

struct SaneBooksAboutView: View {
    static let donationURL: URL = {
        guard let url = URL(string: "https://github.com/sponsors/MrSaneApps") else {
            preconditionFailure("The fixed GitHub Sponsors URL must be valid.")
        }
        return url
    }()

    var body: some View {
        SaneAboutView(
            appName: "ZecBooks",
            githubRepo: "SaneBooks",
            diagnosticsService: .shared,
            licenses: [
                SaneAboutLicenseCatalog.saneUI,
                SaneAboutLicenseCatalog.sparkle,
                zcashSDKLicense
            ],
            feedbackExtraAttachments: [
                ("hand.raised.fill", "Reminder: never attach viewing keys, seeds, memos, or .sanebooks packs")
            ],
            supportAction: .init(title: "Donate on GitHub", url: Self.donationURL),
            labels: .init(
                githubButtonTitle: "Source",
                licensesButtonTitle: "Third-Party Licenses",
                reportBugButtonTitle: "Report Public Issue",
                viewIssuesButtonTitle: "View Public Issues",
                trustPrefix: "Made with",
                trustSuffix: "in the USA",
                secondaryTrustLine: "Never post viewing keys, seeds, txids, memos, proof packs, passphrases, screenshots, or wallet databases.",
                licenseSourceLabel: "Source",
                openSourceButtonTitle: "View Source",
                licensesSheetTitle: "Third-Party Licenses",
                doneButtonTitle: "Done"
            ),
            versionLineText: versionLine,
            identitySymbolName: "books.vertical.fill",
            identitySymbolColor: .saneBooksAccent
        )
    }

    private var versionLine: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "…"
        return "Version \(version) · MIT"
    }

    private var zcashSDKLicense: SaneAboutView.LicenseEntry {
        SaneAboutView.LicenseEntry(
            name: "Zcash Swift Wallet SDK",
            url: "https://github.com/zcash/zcash-swift-wallet-sdk",
            text: """
            MIT License

            Copyright (c) 2020 Zcash

            Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

            The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

            THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
            """
        )
    }
}
