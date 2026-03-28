import XCTest

final class OnboardingFlowUITests: XCTestCase {
    @MainActor
    func testAppLaunches() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.state == .runningForeground)
    }
}
