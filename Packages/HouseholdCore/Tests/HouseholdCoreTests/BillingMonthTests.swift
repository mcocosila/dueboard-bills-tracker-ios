import Foundation
import Testing
import HouseholdCore

@Suite("Current Billing Month")
struct BillingMonthTests {
    @Test("the current Billing Month is the clock's month in the clock's time zone")
    func currentMonthFollowsTheClocksTimeZone() throws {
        // 02:00 UTC on October 1 is still the evening of September 30 in New York.
        let now = try #require(ISO8601DateFormatter().date(from: "2026-10-01T02:00:00Z"))
        let newYork = try #require(TimeZone(identifier: "America/New_York"))
        let household = try Household.open(in: InMemoryHouseholdStore(), clock: .fixed(now, in: newYork))

        #expect(household.currentBillingMonth == BillingMonth(year: 2026, month: 9))
    }
}
