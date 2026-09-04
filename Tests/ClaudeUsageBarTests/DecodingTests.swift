import XCTest
@testable import ClaudeUsageCore

final class DecodingTests: XCTestCase {
    func testDecodesUsageResponse() throws {
        let json = """
        {"five_hour":{"utilization":19.0,"resets_at":"2026-09-04T20:00:00.123456+00:00"},
         "seven_day":{"utilization":66.5,"resets_at":"2026-09-08T21:00:00+00:00"},
         "seven_day_opus":null}
        """.data(using: .utf8)!
        let snap = try UsageSnapshot.decode(json)
        XCTAssertEqual(snap.fiveHour.utilization, 19.0)
        XCTAssertEqual(snap.sevenDay.utilization, 66.5)
        XCTAssertEqual(snap.fiveHour.resetsAt.timeIntervalSince1970, 1788552000.123456, accuracy: 0.001)
        XCTAssertEqual(snap.sevenDay.resetsAt.timeIntervalSince1970, 1788901200, accuracy: 0.001)
    }

    func testMissingResetsAtIsTolerated() throws {
        let json = """
        {"five_hour":{"utilization":0,"resets_at":null},"seven_day":{"utilization":12,"resets_at":"2026-09-08T21:00:00Z"}}
        """.data(using: .utf8)!
        let snap = try UsageSnapshot.decode(json)
        XCTAssertEqual(snap.fiveHour.utilization, 0)
        XCTAssertNil(snap.fiveHour.resetsAtOptional)
    }

    func testDecodesCredentialsBlob() throws {
        let json = """
        {"claudeAiOauth":{"accessToken":"sk-ant-oat01-abc","refreshToken":"r","expiresAt":1788552000000,"scopes":["user:inference"],"subscriptionType":"max"}}
        """.data(using: .utf8)!
        let creds = try ClaudeCredentials.decode(json)
        XCTAssertEqual(creds.accessToken, "sk-ant-oat01-abc")
        XCTAssertEqual(try XCTUnwrap(creds.expiresAt).timeIntervalSince1970, 1788552000, accuracy: 0.001)
        XCTAssertTrue(creds.isExpired(at: Date(timeIntervalSince1970: 1788552001)))
        XCTAssertFalse(creds.isExpired(at: Date(timeIntervalSince1970: 1788551000)))
    }
}
