import XCTest
@testable import ClaudeUsageCore

final class RefreshPolicyTests: XCTestCase {
    func testNoFailuresUsesBaseInterval() {
        XCTAssertEqual(RefreshPolicy.nextDelay(consecutiveRateLimits: 0), 300)
    }

    func testBacksOffExponentiallyAndCaps() {
        XCTAssertEqual(RefreshPolicy.nextDelay(consecutiveRateLimits: 1), 600)
        XCTAssertEqual(RefreshPolicy.nextDelay(consecutiveRateLimits: 2), 1200)
        XCTAssertEqual(RefreshPolicy.nextDelay(consecutiveRateLimits: 3), 1800)
        XCTAssertEqual(RefreshPolicy.nextDelay(consecutiveRateLimits: 10), 1800)
    }

    func testRetryAfterWinsWhenUsefulButIsClamped() {
        XCTAssertEqual(RefreshPolicy.nextDelay(consecutiveRateLimits: 5, retryAfter: 400), 400)
        XCTAssertEqual(RefreshPolicy.nextDelay(consecutiveRateLimits: 0, retryAfter: 30), 300)
        XCTAssertEqual(RefreshPolicy.nextDelay(consecutiveRateLimits: 0, retryAfter: 9999), 1800)
        XCTAssertEqual(RefreshPolicy.nextDelay(consecutiveRateLimits: 1, retryAfter: 0), 600)
    }

    func testTransientFailuresRetryQuicklyThenSettleAtBase() {
        XCTAssertEqual(RefreshPolicy.retryDelay(consecutiveFailures: 1), 15)
        XCTAssertEqual(RefreshPolicy.retryDelay(consecutiveFailures: 2), 30)
        XCTAssertEqual(RefreshPolicy.retryDelay(consecutiveFailures: 3), 60)
        XCTAssertEqual(RefreshPolicy.retryDelay(consecutiveFailures: 4), 120)
        XCTAssertEqual(RefreshPolicy.retryDelay(consecutiveFailures: 5), 240)
        XCTAssertEqual(RefreshPolicy.retryDelay(consecutiveFailures: 6), 300)
        XCTAssertEqual(RefreshPolicy.retryDelay(consecutiveFailures: 20), 300)
        XCTAssertEqual(RefreshPolicy.retryDelay(consecutiveFailures: 0), RefreshPolicy.baseInterval)
    }

    func testStaleness() {
        let t = Date(timeIntervalSince1970: 1_000_000)
        XCTAssertFalse(RefreshPolicy.isStale(fetchedAt: t, now: t.addingTimeInterval(899)))
        XCTAssertTrue(RefreshPolicy.isStale(fetchedAt: t, now: t.addingTimeInterval(901)))
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
