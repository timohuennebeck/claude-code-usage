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

    func testDecodesScopedModelLimits() throws {
        let json = """
        {"five_hour":{"utilization":46,"resets_at":"2026-09-04T16:00:00+00:00"},
         "seven_day":{"utilization":17,"resets_at":"2026-09-09T16:00:00+00:00"},
         "seven_day_opus":null,
         "limits":[
           {"kind":"session","group":"session","percent":46,"resets_at":"2026-09-04T16:00:00+00:00","scope":null},
           {"kind":"weekly_all","group":"weekly","percent":17,"resets_at":"2026-09-09T16:00:00+00:00","scope":null},
           {"kind":"weekly_scoped","group":"weekly","percent":23,"resets_at":"2026-09-09T16:00:00+00:00","scope":{"model":{"id":null,"display_name":"Fable"},"surface":null}},
           {"kind":"weekly_scoped","group":"weekly","percent":5,"resets_at":null,"scope":{"model":null,"surface":"cowork"}}
         ]}
        """.data(using: .utf8)!
        let snap = try UsageSnapshot.decode(json)
        XCTAssertEqual(snap.scoped.map(\.label), ["Fable", "cowork"])
        XCTAssertEqual(snap.scoped[0].limit.utilization, 23)
        XCTAssertEqual(snap.scoped[0].limit.resetsAtOptional?.timeIntervalSince1970, 1788969600)
        XCTAssertNil(snap.scoped[1].limit.resetsAtOptional)
    }

    func testNoLimitsArrayMeansNoScopedLimits() throws {
        let json = """
        {"five_hour":{"utilization":1,"resets_at":null},"seven_day":{"utilization":2,"resets_at":null}}
        """.data(using: .utf8)!
        XCTAssertEqual(try UsageSnapshot.decode(json).scoped, [])
    }
}
