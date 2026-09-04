import XCTest
@testable import ClaudeUsageCore

final class RefreshPolicyTests: XCTestCase {
    func testNoFailuresUsesBaseInterval() {
        XCTAssertEqual(RefreshPolicy.nextDelay(consecutiveRateLimits: 0), 180)
    }

    func testBacksOffExponentiallyAndCaps() {
        XCTAssertEqual(RefreshPolicy.nextDelay(consecutiveRateLimits: 1), 360)
        XCTAssertEqual(RefreshPolicy.nextDelay(consecutiveRateLimits: 2), 720)
        XCTAssertEqual(RefreshPolicy.nextDelay(consecutiveRateLimits: 3), 1440)
        XCTAssertEqual(RefreshPolicy.nextDelay(consecutiveRateLimits: 4), 1800)
        XCTAssertEqual(RefreshPolicy.nextDelay(consecutiveRateLimits: 10), 1800)
    }

    func testRetryAfterWinsWhenUsefulButIsClamped() {
        XCTAssertEqual(RefreshPolicy.nextDelay(consecutiveRateLimits: 5, retryAfter: 300), 300)
        XCTAssertEqual(RefreshPolicy.nextDelay(consecutiveRateLimits: 0, retryAfter: 30), 180)
        XCTAssertEqual(RefreshPolicy.nextDelay(consecutiveRateLimits: 0, retryAfter: 9999), 1800)
        XCTAssertEqual(RefreshPolicy.nextDelay(consecutiveRateLimits: 1, retryAfter: 0), 360)
    }

    func testStaleness() {
        let t = Date(timeIntervalSince1970: 1_000_000)
        XCTAssertFalse(RefreshPolicy.isStale(fetchedAt: t, now: t.addingTimeInterval(599)))
        XCTAssertTrue(RefreshPolicy.isStale(fetchedAt: t, now: t.addingTimeInterval(601)))
    }

    func testSnapshotRoundTripsThroughJSON() throws {
        let t = Date(timeIntervalSince1970: 1_000_000)
        let snap = UsageSnapshot(
            fiveHour: UsageLimit(utilization: 11, resetsAt: t.addingTimeInterval(3600)),
            sevenDay: UsageLimit(utilization: 20, resetsAt: nil),
            scoped: [ScopedLimit(label: "Fable", limit: UsageLimit(utilization: 25, resetsAt: t))],
            fetchedAt: t)
        let data = try JSONEncoder().encode(snap)
        XCTAssertEqual(try JSONDecoder().decode(UsageSnapshot.self, from: data), snap)
    }
}
