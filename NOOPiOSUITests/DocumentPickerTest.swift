import XCTest

final class DocumentPickerTest: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-noop.onboarded", "YES",
                                "-noop.lastSeenChangelogVersion", "1.69"]
        app.launch()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 15),
                      "Main tab view did not appear")
    }

    override func tearDownWithError() throws {
        app.terminate()
    }

    private func snap(_ name: String) {
        let a = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        a.name = name; a.lifetime = .keepAlways; add(a)
    }

    // MARK: - Debug

    func testDebugMoreTabTree() {
        let tabBar = app.tabBars.firstMatch
        tabBar.buttons.element(boundBy: tabBar.buttons.count - 1).tap()
        sleep(3)
        snap("debug-more-tab")
        // Dump element types to understand the More-tab view hierarchy
        print("=== DESCENDANTS ===")
        let types: [XCUIElement.ElementType] = [
            .table, .collectionView, .scrollView,
            .cell, .navigationBar, .staticText, .button
        ]
        for t in types {
            let matches = app.descendants(matching: t).allElementsBoundByIndex
            if !matches.isEmpty {
                print("TYPE=\(t.rawValue): \(matches.count) elements")
                matches.prefix(5).forEach { print("  [\($0.elementType.rawValue)] label='\($0.label)' id='\($0.identifier)'") }
            }
        }
        // Also dump all staticTexts to see what text is visible
        print("=== ALL STATIC TEXTS ===")
        app.staticTexts.allElementsBoundByIndex.prefix(40).forEach {
            print("  ST label='\($0.label)'")
        }
    }

    // MARK: - Navigate to DataSourcesView

    private func openDataSources() throws {
        // "More" tab is the last one
        let tabBar = app.tabBars.firstMatch
        tabBar.buttons.element(boundBy: tabBar.buttons.count - 1).tap()
        sleep(3)
        snap("01-more-tab")

        // Scroll until "Data Sources" is hittable — swipe on the whole screen
        // (list may be a SwiftUI ScrollView/CollectionView, not always app.tables).
        var found = false
        for _ in 0..<6 {
            let el = app.staticTexts.matching(
                NSPredicate(format: "label == 'Data Sources'")
            ).firstMatch
            if el.exists && el.isHittable {
                el.tap()
                found = true
                break
            }
            app.swipeUp()
            sleep(1)
        }

        if !found {
            // Dump what staticTexts are visible for diagnosis
            print("=== staticTexts after scrolling ===")
            app.staticTexts.allElementsBoundByIndex.prefix(30).forEach {
                print("  ST label='\($0.label)' hittable=\($0.isHittable)")
            }
            snap("01b-scroll-exhausted")
        }

        XCTAssertTrue(found, "Could not reach 'Data Sources' row after scrolling")
        sleep(1)
        snap("02-datasources-view")
    }

    // MARK: - Picker verification

    /// Returns true the moment UIDocumentPickerViewController is on screen.
    private func pickerIsPresented() -> Bool {
        return app.navigationBars["Browse"].waitForExistence(timeout: 8)
            || app.navigationBars["Recents"].waitForExistence(timeout: 2)
            || app.buttons["Cancel"].waitForExistence(timeout: 2)
    }

    func testWhoopPickerPresentsDocumentPicker() throws {
        try openDataSources()

        // WHOOP card's import button label: "Choose export…"
        let btn = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH[c] 'choose export'")
        ).firstMatch
        XCTAssertTrue(btn.waitForExistence(timeout: 6),
            "WHOOP import button not found — visible: \(app.buttons.allElementsBoundByIndex.prefix(10).map(\.label))")
        btn.tap()

        snap("03-after-tap")
        XCTAssertTrue(pickerIsPresented(),
            "UIDocumentPickerViewController did NOT appear — UIKit bypass may not have fired")
        snap("04-picker-open")

        // Check selectability of the planted zip in the picker
        verifyZipSelectable()

        if app.buttons["Cancel"].exists { app.buttons["Cancel"].tap() }
    }

    func testAppleHealthPickerPresentsDocumentPicker() throws {
        try openDataSources()

        let btn = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'export.zip'")
        ).firstMatch
        XCTAssertTrue(btn.waitForExistence(timeout: 6), "Apple Health picker button not found")
        btn.tap()

        snap("05-ah-picker")
        XCTAssertTrue(pickerIsPresented(), "UIDocumentPickerViewController not presented for Apple Health")
        snap("06-ah-picker-open")
        if app.buttons["Cancel"].exists { app.buttons["Cancel"].tap() }
    }

    // MARK: - Zip selectability

    private func verifyZipSelectable() {
        // Picker opens on "Recents". Navigate to Browse → On My iPhone to find the planted zip.
        // Picker bottom bar: Recents / Shared / Browse
        // Use firstMatch to avoid ambiguity if another "Browse" element exists on screen.
        let browseTab = app.buttons.matching(NSPredicate(format: "label == 'Browse'")).firstMatch
        if browseTab.waitForExistence(timeout: 4) {
            browseTab.tap()
            sleep(1)
            snap("04a-browse")
        }

        // "On My iPhone" or device-name cell in the Browse sidebar
        let onMyPhone = app.cells.matching(
            NSPredicate(format: "label CONTAINS[c] 'iPhone'")
        ).firstMatch
        if onMyPhone.waitForExistence(timeout: 4) {
            snap("04b-browse-locations")
            onMyPhone.tap()
            sleep(1)
        }

        // The NOOP app's Files container (labeled "NOOP")
        let noopFolder = app.cells.matching(
            NSPredicate(format: "label == 'NOOP'")
        ).firstMatch
        if noopFolder.waitForExistence(timeout: 3) {
            noopFolder.tap()
            sleep(1)
            snap("04c-noop-folder")
        }

        // Find the planted zip
        let zipCell = app.cells.matching(
            NSPredicate(format: "label CONTAINS 'test_whoop_export'")
        ).firstMatch
        if zipCell.waitForExistence(timeout: 4) {
            snap("04d-zip-found")
            XCTAssertTrue(zipCell.isEnabled,
                "test_whoop_export.zip is GREYED OUT — UIKit [.data] picker is still filtering zips")
            print("✅ test_whoop_export.zip is ENABLED (selectable) in UIKit picker")
        } else {
            print("⚠️  test_whoop_export.zip not visible — dumping all cells:")
            app.cells.allElementsBoundByIndex.prefix(20).forEach { print("  CELL: \($0.label)") }
            snap("04e-picker-contents")
        }
    }
}
