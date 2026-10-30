import XCTest

@MainActor
final class HistoryDetailLayoutUITests: XCTestCase {
    func testDefaultLayoutForAllOutcomes() {
        verifyDetails(category: "UICTContentSizeCategoryL", name: "default")
    }

    func testAccessibilityLayoutForAllOutcomes() {
        verifyDetails(category: "UICTContentSizeCategoryAccessibilityXXXL", name: "accessibility")
    }

    private func verifyDetails(category: String, name: String) {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--game-testing", "--ui-testing", "--history-demo",
                               "-UIPreferredContentSizeCategoryName", category]
        app.launch()
        XCTAssertTrue(app.buttons["history"].waitForExistence(timeout: 8))
        app.buttons["history"].tap()
        for (index, outcome) in [(1, "won"), (2, "mistakes"), (4, "timedOut")] {
            let row = app.buttons[String(format: "history-game-00000000-0000-0000-0000-%012d", index)]
            for _ in 0..<12 {
                if row.isHittable { break }
                app.swipeUp()
            }
            XCTAssertTrue(row.isHittable)
            row.tap()
            let title = app.staticTexts["history-detail-title"]
            XCTAssertTrue(title.waitForExistence(timeout: 5))
            let viewport = app.scrollViews["history-detail-content"]
            let back = app.buttons["history-detail-back"]
            let header = app.staticTexts["history-detail-header"]
            let message = app.staticTexts["history-detail-title-message"]
            let date = app.staticTexts["history-detail-date"]
            let time = app.staticTexts["history-detail-time"]
            let stats = ["level", "time", "mistakes"].map {
                app.descendants(matching: .any).matching(identifier: "history-detail-stat-\($0)").firstMatch
            }
            XCTAssertGreaterThanOrEqual(viewport.frame.minY, back.frame.maxY - 1)
            // UIKit can include the bottom safe area in the reported scroll-view frame.
            // The layout itself uses the safe content height from GeometryReader.
            XCTAssertGreaterThanOrEqual(title.frame.minY, viewport.frame.midY - 1)
            XCTAssertLessThanOrEqual(title.frame.minY, viewport.frame.midY + 23)
            XCTAssertLessThanOrEqual(title.frame.maxY, message.frame.minY)
            XCTAssertLessThanOrEqual(message.frame.maxY, date.frame.minY)
            XCTAssertLessThanOrEqual(date.frame.maxY, time.frame.minY)
            for element in [title, message, date, time] + stats {
                XCTAssertTrue(element.exists)
                XCTAssertGreaterThanOrEqual(element.frame.minX, 31)
                XCTAssertLessThanOrEqual(element.frame.maxX, app.frame.maxX - 31)
            }
            if category == "UICTContentSizeCategoryAccessibilityXXXL" {
                XCTAssertLessThanOrEqual(stats[0].frame.maxY, stats[1].frame.minY)
                XCTAssertLessThanOrEqual(stats[1].frame.maxY, stats[2].frame.minY)
            }
            let originalBackY = back.frame.minY
            let originalHeaderY = header.frame.minY
            let geometry = XCTAttachment(string: "screen=\(app.frame)\nscrollView=\(viewport.frame)\ntitle=\(title.frame)\nmessage=\(message.frame)\ndate=\(date.frame)\ntime=\(time.frame)\nstats=\(stats.map(\.frame))")
            geometry.name = "details-geometry-\(name)-\(outcome)"
            geometry.lifetime = .keepAlways
            add(geometry)
            capture(app, "details-\(name)-\(outcome)-top")
            for stat in stats {
                for _ in 0..<12 {
                    if stat.isHittable && stat.frame.minY >= viewport.frame.minY && stat.frame.maxY <= viewport.frame.maxY { break }
                    viewport.swipeUp()
                }
                XCTAssertTrue(stat.isHittable, "Every game statistic must remain reachable")
                XCTAssertLessThanOrEqual(stat.frame.maxY, viewport.frame.maxY + 1)
            }
            capture(app, "details-\(name)-\(outcome)-stats")
            XCTAssertTrue(back.isHittable)
            XCTAssertEqual(back.frame.minY, originalBackY, accuracy: 1)
            XCTAssertEqual(header.frame.minY, originalHeaderY, accuracy: 1)
            back.tap()
            XCTAssertTrue(app.buttons["history-close"].waitForExistence(timeout: 5))
        }
    }

    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
