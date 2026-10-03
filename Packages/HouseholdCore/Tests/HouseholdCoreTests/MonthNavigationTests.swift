import Foundation
import Testing
import HouseholdCore

/// The clock is `.testing`: September 15, 2026 in New York, so September 2026 is the current Billing Month.
@Suite("Stepping between Billing Months")
struct MonthNavigationTests {
    let september = BillingMonth(year: 2026, month: 9)

    @Test("the month after the current one can be opened, with its Dues")
    func theMonthAfterTheCurrentOneCanBeOpened() throws {
        var household = try Household.open(in: InMemoryHouseholdStore(), clock: .testing)
        try household.addBill(.cityPower(in: household))

        let board = try household.openBillingMonth(BillingMonth(year: 2026, month: 10))

        #expect(board.dues.map(\.dueDate) == [DueDate(year: 2026, month: 10, day: 17)])
    }

    @Test("two months ahead cannot be opened, and the refusal says why")
    func twoMonthsAheadCannotBeOpened() throws {
        var household = try Household.open(in: InMemoryHouseholdStore(), clock: .testing)

        let refusal = #expect(throws: BillingMonthRefusal.tooFarAhead) {
            try household.openBillingMonth(BillingMonth(year: 2026, month: 11))
        }

        #expect(refusal?.localizedDescription == "Only the month after the current one can be opened yet")
    }

    @Test("a past month can be opened, with its Dues")
    func aPastMonthCanBeOpened() throws {
        var household = try Household.open(in: InMemoryHouseholdStore(), clock: .testing)
        try household.addBill(.cityPower(in: household))

        let board = try household.openBillingMonth(BillingMonth(year: 2026, month: 7))

        #expect(board.dues.map(\.dueDate) == [DueDate(year: 2026, month: 7, day: 17)])
    }

    @Test("previous and next step one month, across the year boundary")
    func previousAndNextCrossTheYearBoundary() throws {
        var household = try Household.open(in: InMemoryHouseholdStore(), clock: .testing)

        let january = try household.openBillingMonth(BillingMonth(year: 2026, month: 1))

        #expect(january.previous == BillingMonth(year: 2025, month: 12))
        #expect(january.next == BillingMonth(year: 2026, month: 2))
    }

    @Test("there is no next beyond the month after the current one")
    func nextIsAbsentBeyondTheMonthAfterTheCurrentOne() throws {
        var household = try Household.open(in: InMemoryHouseholdStore(), clock: .testing)

        #expect(try household.openBillingMonth(september).next == BillingMonth(year: 2026, month: 10))
        #expect(try household.openBillingMonth(BillingMonth(year: 2026, month: 10)).next == nil)
    }

    @Test("the earliest Billing Month has no previous, and nothing before it can be opened")
    func theEarliestMonthHasNoPrevious() throws {
        var household = try Household.open(in: InMemoryHouseholdStore(), clock: .testing)

        #expect(try household.openBillingMonth(BillingMonth(year: 1, month: 1)).previous == nil)
        #expect(throws: BillingMonthRefusal.notACalendarMonth) {
            try household.openBillingMonth(BillingMonth(year: 0, month: 12))
        }
    }

    @Test("a month number outside 1 to 12 is not a Billing Month", arguments: [0, 13])
    func aMonthOutsideTheCalendarIsRefused(month: Int) throws {
        var household = try Household.open(in: InMemoryHouseholdStore(), clock: .testing)

        let refusal = #expect(throws: BillingMonthRefusal.notACalendarMonth) {
            try household.openBillingMonth(BillingMonth(year: 2026, month: month))
        }

        #expect(refusal?.localizedDescription == "There is no such month")
    }

    @Test("the next month is worked out in the clock's time zone")
    func theLatestOpenableMonthFollowsTheClocksTimeZone() throws {
        // 02:00 UTC on October 1 is still September 30 in New York, so November is two months ahead.
        let now = try #require(ISO8601DateFormatter().date(from: "2026-10-01T02:00:00Z"))
        let newYork = try #require(TimeZone(identifier: "America/New_York"))
        var household = try Household.open(in: InMemoryHouseholdStore(), clock: .fixed(now, in: newYork))

        #expect(throws: BillingMonthRefusal.tooFarAhead) {
            try household.openBillingMonth(BillingMonth(year: 2026, month: 11))
        }
    }
}
