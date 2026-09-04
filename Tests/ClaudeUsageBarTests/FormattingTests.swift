import XCTest
@testable import ClaudeUsageCore

final class FormattingTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1_000_000)

    func testFiveHourRemainingUsesHoursAndMinutes() {
        let reset = now.addingTimeInterval(2 * 3600 + 41 * 60 + 30)
        XCTAssertEqual(UsageFormatting.remaining(until: reset, now: now, window: .fiveHour), "2h 41m")
    }

    func testFiveHourUnderAnHourKeepsZeroHours() {
        let reset = now.addingTimeInterval(24 * 60)
        XCTAssertEqual(UsageFormatting.remaining(until: reset, now: now, window: .fiveHour), "0h 24m")
    }

    func testSevenDayOverADayUsesDaysAndHours() {
        let reset = now.addingTimeInterval(4 * 86400 + 4 * 3600 + 59 * 60)
        XCTAssertEqual(UsageFormatting.remaining(until: reset, now: now, window: .sevenDay), "4d 4h")
    }

    func testSevenDayUnderADayFallsBackToHoursAndMinutes() {
        let reset = now.addingTimeInterval(5 * 3600 + 3 * 60)
        XCTAssertEqual(UsageFormatting.remaining(until: reset, now: now, window: .sevenDay), "5h 3m")
    }

    func testPastResetShowsNow() {
        XCTAssertEqual(UsageFormatting.remaining(until: now.addingTimeInterval(-5), now: now, window: .fiveHour), "now")
    }

    func testPercentTextRounds() {
        XCTAssertEqual(UsageFormatting.percentText(18.6), "19%")
        XCTAssertEqual(UsageFormatting.percentText(0), "0%")
        XCTAssertEqual(UsageFormatting.percentText(100), "100%")
    }

    func testSeverityThresholds() {
        XCTAssertEqual(UsageSeverity(utilization: 19), .normal)
        XCTAssertEqual(UsageSeverity(utilization: 59.9), .normal)
        XCTAssertEqual(UsageSeverity(utilization: 60), .approaching)
        XCTAssertEqual(UsageSeverity(utilization: 84.9), .approaching)
        XCTAssertEqual(UsageSeverity(utilization: 85), .critical)
        XCTAssertEqual(UsageSeverity(utilization: 100), .critical)
    }
}
