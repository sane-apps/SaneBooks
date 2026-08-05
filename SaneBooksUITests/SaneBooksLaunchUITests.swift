import XCTest

@MainActor
final class SaneBooksLaunchUITests: XCTestCase {
    func testAbbreviatedOnboardingExplainsCriticalBoundariesAndRoutesBothUsers() {
        let owner = makeApp(scene: "onboarding")
        owner.launch()
        XCTAssertTrue(owner.windows.firstMatch.waitForExistence(timeout: 10))
        XCTAssertTrue(owner.descendants(matching: .any)["sanebooks.onboarding"].exists)
        XCTAssertTrue(owner.staticTexts["View activity without moving money"].exists)
        XCTAssertTrue(owner.staticTexts["SAFE, READ-ONLY ACCESS"].exists)
        keepScreenshot(owner, name: "onboarding-first")

        let next = owner.buttons["Continue"]
        XCTAssertTrue(waitForHittability(of: next, timeout: 5))
        next.click()
        XCTAssertTrue(owner.staticTexts["Keep your books on your Mac"].waitForExistence(timeout: 5))
        XCTAssertTrue(owner.buttons["Back"].isHittable)
        next.click()
        XCTAssertTrue(owner.staticTexts["Share only what is needed"].waitForExistence(timeout: 5))
        keepScreenshot(owner, name: "onboarding-final")

        let startOwner = owner.buttons["Import Viewing Key"]
        XCTAssertTrue(startOwner.isHittable)
        startOwner.click()
        XCTAssertTrue(owner.buttons["Import from Zashi / Zodl…"].waitForExistence(timeout: 5))
        let setupTitle = owner.staticTexts["Set Up Your Books"]
        XCTAssertTrue(setupTitle.exists)
        XCTAssertLessThan(setupTitle.frame.height, 40, "The standard setup heading should not dominate the form.")
        let liveSample = owner.buttons["See live sample"]
        let offlineDemo = owner.buttons["Open offline demo"]
        XCTAssertTrue(liveSample.waitForExistence(timeout: 5))
        XCTAssertTrue(liveSample.isHittable, "The setup footer must not cover the sample actions.")
        XCTAssertTrue(offlineDemo.isHittable, "The setup footer must not cover the demo action.")
        keepScreenshot(owner, name: "setup-books")
        owner.terminate()

        let reader = makeApp(
            scene: "onboarding",
            extraArguments: ["--e2e-accessibility-text", "--e2e-layout-rtl"]
        )
        defer { reader.terminate() }
        reader.launch()
        XCTAssertTrue(reader.windows.firstMatch.waitForExistence(timeout: 10))
        let readerScroll = reader.scrollViews.firstMatch
        for _ in 0 ..< 2 {
            let continueButton = reader.buttons["Continue"]
            if !continueButton.isHittable {
                readerScroll.swipeUp(velocity: .slow)
            }
            XCTAssertTrue(waitForHittability(of: continueButton, timeout: 5))
            continueButton.click()
        }
        let startReader = reader.buttons["Open Accountant Reader"]
        XCTAssertTrue(startReader.waitForExistence(timeout: 5))
        if !startReader.isHittable {
            readerScroll.swipeUp(velocity: .slow)
        }
        XCTAssertTrue(startReader.isHittable)
        let finalHeading = reader.staticTexts["Share only what is needed"]
        XCTAssertTrue(finalHeading.exists)
        XCTAssertLessThan(finalHeading.frame.height, 90, "Large text must remain readable without overwhelming the screen.")
        keepScreenshot(reader, name: "onboarding-extra-large-rtl")
        startReader.click()
        XCTAssertTrue(reader.buttons["Choose File…"].waitForExistence(timeout: 5))
    }

    func testForcedWelcomeScenePresentsPrimaryJourneys() {
        let app = makeApp(scene: "welcome")
        defer { app.terminate() }
        app.launch()

        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["ZecBooks"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Test data — not saved"].exists)
        XCTAssertTrue(app.staticTexts["Private books for shielded Zcash"].exists)
        XCTAssertTrue(app.buttons["Import Viewing Key"].isHittable)
        XCTAssertTrue(app.buttons["Open Proof Pack Reader"].isHittable)
        XCTAssertTrue(app.staticTexts["This app cannot spend ZEC. Never paste a seed phrase."].exists)
        keepScreenshot(app, name: "welcome-minimum")
    }

    func testPrimaryWelcomeJourneysAreReachable() {
        let app = makeApp(scene: "welcome")
        defer { app.terminate() }
        app.launch()
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 10))

        app.buttons["Import Viewing Key"].click()
        XCTAssertTrue(app.buttons["Import from Zashi / Zodl…"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Or enter a viewing key — never recovery words"].exists)
        XCTAssertTrue(app.staticTexts["Wallet start date (optional — speeds up first sync)"].exists)

        app.buttons["Cancel"].click()
        XCTAssertTrue(app.buttons["Open Proof Pack Reader"].waitForExistence(timeout: 5))
        app.buttons["Open Proof Pack Reader"].click()
        let chooseFile = app.buttons["Choose File…"]
        XCTAssertTrue(chooseFile.waitForExistence(timeout: 5))
        XCTAssertTrue(chooseFile.isHittable)
        XCTAssertTrue(
            app.staticTexts["Open a proof pack your accountant shared with you. No wallet key needed."].exists
        )
        XCTAssertFalse(app.buttons["Unlock"].isEnabled)
        keepScreenshot(app, name: "reader-minimum")
    }

    func testLedgerPrimaryNavigationRemainsVisible() {
        let app = makeApp(scene: "ledger")
        defer { app.terminate() }
        app.launch()

        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 10))
        XCTAssertGreaterThanOrEqual(window.frame.width, 820)
        XCTAssertGreaterThanOrEqual(window.frame.height, 600)

        let vaultButton = app.buttons["sanebooks.nav.vault"]
        XCTAssertTrue(vaultButton.waitForExistence(timeout: 10))
        XCTAssertTrue(vaultButton.isHittable)
        XCTAssertTrue(app.buttons["sanebooks.nav.proof-packs"].isHittable)
        XCTAssertTrue(app.buttons["sanebooks.nav.settings"].isHittable)
        XCTAssertTrue(app.buttons["New Proof Pack"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["New Proof Pack"].isHittable)
        keepScreenshot(app, name: "ledger-minimum")
    }

    func testLedgerFiltersAndDiscreetControlHaveAccessibleTargets() {
        let app = makeApp(scene: "ledger")
        defer { app.terminate() }
        app.launch()

        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any)["sanebooks.filter.kind"].isHittable)
        XCTAssertTrue(app.descendants(matching: .any)["sanebooks.filter.year"].isHittable)
        XCTAssertTrue(app.descendants(matching: .any)["sanebooks.filter.untagged-only"].isHittable)
        XCTAssertTrue(app.textFields["sanebooks.filter.search"].isHittable)
        XCTAssertTrue(app.buttons["sanebooks.privacy.discreet-mode"].isHittable)
        keepScreenshot(app, name: "ledger-accessibility-targets")
    }

    func testProofPackDatesAndNestedBackNavigationHaveAccessibleTargets() {
        let pack = makeApp(scene: "pack")
        defer { pack.terminate() }
        pack.launch()

        XCTAssertTrue(pack.windows.firstMatch.waitForExistence(timeout: 10))
        XCTAssertTrue(pack.buttons["sanebooks.nav.back-to-ledger"].isHittable)
        XCTAssertTrue(pack.buttons["sanebooks.pack.date.from"].isHittable)
        XCTAssertTrue(pack.buttons["sanebooks.pack.date.to"].isHittable)
        keepScreenshot(pack, name: "proof-pack-minimum")
    }

    func testShareFlowKeepsDisclosureAndExportControlsReachable() {
        let app = makeApp(scene: "share")
        defer { app.terminate() }
        app.launch()

        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Share Proof Pack"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Disclosure audit"].exists)

        let saveFile = app.buttons["Save File…"]
        XCTAssertTrue(saveFile.waitForExistence(timeout: 5))
        XCTAssertTrue(saveFile.isHittable)

        let encryptedFormat = app.radioButtons["Encrypted pack for your accountant"]
        if !encryptedFormat.isHittable {
            app.scrollViews.firstMatch.swipeUp()
        }
        XCTAssertTrue(encryptedFormat.waitForExistence(timeout: 5))
        XCTAssertTrue(encryptedFormat.isHittable)
        let incompleteHistory = app.checkBoxes["I understand these totals may be incomplete"]
        XCTAssertTrue(incompleteHistory.waitForExistence(timeout: 5))
        XCTAssertTrue(incompleteHistory.isHittable)
        keepScreenshot(app, name: "share-minimum")
    }

    func testAdaptiveEnvironmentMatrixKeepsCoreControlsReachable() {
        let baseline = makeApp(scene: "ledger")
        baseline.launch()
        XCTAssertTrue(baseline.windows.firstMatch.waitForExistence(timeout: 10))
        let baselineVaultName = baseline.staticTexts["sanebooks.vault.name"]
        XCTAssertTrue(baselineVaultName.waitForExistence(timeout: 5))
        let baselineTextHeight = baselineVaultName.frame.height
        baseline.terminate()

        let configurations: [(name: String, arguments: [String])] = [
            ("rtl", ["--e2e-layout-rtl"]),
            ("accessibility-text", ["--e2e-accessibility-text"])
        ]

        for configuration in configurations {
            let app = makeApp(scene: "ledger", extraArguments: configuration.arguments)
            app.launch()

            XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 10))
            XCTAssertTrue(app.buttons["sanebooks.nav.vault"].isHittable)
            XCTAssertTrue(app.buttons["sanebooks.nav.proof-packs"].isHittable)
            XCTAssertTrue(app.buttons["sanebooks.nav.settings"].isHittable)
            XCTAssertTrue(app.buttons["New Proof Pack"].isHittable)
            keepScreenshot(app, name: "ledger-\(configuration.name)")
            if configuration.name == "accessibility-text" {
                let enlargedVaultName = app.staticTexts["sanebooks.vault.name"]
                XCTAssertTrue(enlargedVaultName.waitForExistence(timeout: 5))
                XCTAssertGreaterThan(
                    enlargedVaultName.frame.height,
                    baselineTextHeight * 1.2,
                    "Accessibility text must visibly scale, not only keep controls reachable."
                )

                let outerScrollView = app.scrollViews["sanebooks.ledger.large-text-scroll"]
                XCTAssertTrue(outerScrollView.waitForExistence(timeout: 5))
                let rowsScrollView = app.scrollViews["sanebooks.ledger.rows-scroll"]
                XCTAssertTrue(rowsScrollView.waitForExistence(timeout: 5))
                let ledgerRow = app.descendants(matching: .any)["sanebooks.ledger.note-row"].firstMatch
                XCTAssertTrue(ledgerRow.waitForExistence(timeout: 5))
                for _ in 0 ..< 4 where !ledgerRow.isHittable {
                    outerScrollView.swipeUp(velocity: .slow)
                }
                XCTAssertTrue(
                    waitForHittability(of: ledgerRow, timeout: 5),
                    "Large-text users must reach rows by scrolling the ledger once, without a nested vertical scroller."
                )
                XCTAssertTrue(rowsScrollView.isHittable)
                keepScreenshot(app, name: "ledger-accessibility-text-scrolled")
            }
            app.terminate()
        }
    }

    func testKeyboardShortcutsReachPrimaryJourneys() {
        let app = makeApp(scene: "ledger")
        defer { app.terminate() }
        app.launch()

        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 10))
        app.typeKey("n", modifierFlags: .command)
        XCTAssertTrue(app.staticTexts["New Proof Pack"].waitForExistence(timeout: 5))

        app.typeKey("i", modifierFlags: .command)
        XCTAssertTrue(app.buttons["Import from Zashi / Zodl…"].waitForExistence(timeout: 5))

        app.typeKey("o", modifierFlags: .command)
        XCTAssertTrue(app.buttons["Choose File…"].waitForExistence(timeout: 5))
        keepScreenshot(app, name: "keyboard-reader-journey")
    }

    func testAboutDonationControlIsVisibleAndReachable() {
        let app = makeApp(scene: "welcome")
        defer { app.terminate() }
        app.launch()

        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 10))
        app.typeKey(",", modifierFlags: .command)

        let about = app.buttons["About"]
        XCTAssertTrue(about.waitForExistence(timeout: 5))
        XCTAssertTrue(about.isHittable)
        about.click()

        let donate = app.buttons["Donate on GitHub"]
        XCTAssertTrue(donate.waitForExistence(timeout: 5))
        XCTAssertTrue(donate.isHittable)

        let report = app.buttons["Report Public Issue"]
        XCTAssertTrue(report.waitForExistence(timeout: 5))
        XCTAssertTrue(report.isHittable)
        report.click()

        let feedbackTitle = app.staticTexts["Report an Issue"]
        XCTAssertTrue(feedbackTitle.waitForExistence(timeout: 5))
        keepScreenshot(app, name: "about-bug-report")

        let cancel = app.buttons["Cancel"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 3))
        cancel.click()

        XCTAssertTrue(donate.waitForExistence(timeout: 5))
        keepScreenshot(app, name: "about-donation")
        app.typeKey("w", modifierFlags: .command)
    }

    func testPrivateZashiImportScenesWhenFixtureProvided() throws {
        guard let fixturePath = ProcessInfo.processInfo.environment["SANEBOOKS_E2E_ZASHI_DB"],
              FileManager.default.fileExists(atPath: fixturePath)
        else {
            throw XCTSkip("Set SANEBOOKS_E2E_ZASHI_DB to run the private wallet-import scene matrix.")
        }

        verifyPrivateZashiScene("zashi-ledger", expectedText: "ZecBooks", fixturePath: fixturePath)
        verifyPrivateZashiScene("zashi-detail", expectedText: "Transaction", fixturePath: fixturePath)
        verifyPrivateZashiScene("zashi-pack", expectedText: "New Proof Pack", fixturePath: fixturePath)
        verifyPrivateZashiScene("zashi-share", expectedText: "Share Proof Pack", fixturePath: fixturePath)
    }

    private func verifyPrivateZashiScene(
        _ scene: String,
        expectedText: String,
        fixturePath: String
    ) {
        let app = makeApp(
            scene: scene,
            extraArguments: ["--e2e-import-db=\(fixturePath)"]
        )
        defer { app.terminate() }
        app.launch()

        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts[expectedText].waitForExistence(timeout: 15))

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "SaneBooks-\(scene)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func makeApp(
        scene: String,
        extraArguments: [String] = []
    ) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["SANEBOOKS_FORCE_MOCK"] = "1"
        app.launchEnvironment["SANEAPPS_DISABLE_KEYCHAIN"] = "1"
        app.launchArguments = [
            "-ApplePersistenceIgnoreState",
            "YES",
            "--e2e-scene=\(scene)",
            "--sane-no-keychain"
        ] + extraArguments
        addTeardownBlock {
            app.terminate()
        }
        return app
    }

    private func keepScreenshot(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "SaneBooks-\(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func waitForHittability(of element: XCUIElement, timeout: TimeInterval) -> Bool {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "hittable == true"),
            object: element
        )
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }
}
