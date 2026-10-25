#if canImport(UIKit)
import XCTest
import UIKit
@testable import Sudokuly

final class AppIntegrationTests: XCTestCase {
    @MainActor
    func testBundledBricolageWeightsAreRegisteredAndUsedWithoutFallback() throws {
        XCTAssertNotNil(Bundle.main.url(forResource: "BricolageGrotesque-Variable", withExtension: "ttf"))
        let weights: [(String, UIFont.Weight)] = [
            ("Regular", .regular), ("Medium", .medium),
            ("SemiBold", .semibold), ("Bold", .bold)
        ]
        for (face, weight) in weights {
            let name = "BricolageGrotesque-96ptExtraBold_\(face)"
            let font = try XCTUnwrap(UIFont(name: name, size: 20), "Missing bundled Bricolage \(face)")
            XCTAssertEqual(font.fontName, name)
            XCTAssertEqual(AppFont.uiFont(20, weight: weight).fontName, name)
        }
    }

    @MainActor
    func testBackgroundPausesClockAndRequiresManualResume() async throws {
        let model = GameViewModel(history: GameHistoryStore(ownerID: "test-player"))
        model.start(.easy)
        for _ in 0..<100 where model.session == nil {
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertNotNil(model.session)
        model.setAppActive(false)
        XCTAssertTrue(model.isPaused)
        let elapsed = model.session!.elapsed
        try await Task.sleep(nanoseconds: 250_000_000)
        model.tick()
        XCTAssertEqual(model.session!.elapsed, elapsed)
        model.setAppActive(true)
        XCTAssertTrue(model.isPaused)
        model.resume()
        try await Task.sleep(nanoseconds: 50_000_000)
        model.tick()
        XCTAssertGreaterThan(model.session!.elapsed, elapsed)
        model.goHome()
        XCTAssertNil(model.session)
    }
}
#endif
