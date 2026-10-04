import Foundation
import Testing
import HouseholdCore

/// Mirrors the web app's Overdue tests: each moves a Due Date relative to today; here the
/// clock moves instead, since a Due Date is fixed once its Due is generated.
@Suite("Due Soon and Overdue")
struct DueStateTests {
    /// The state of the Due for City Power, due on `dueDay` of `dueMonth`, in `month`, as of `clock`.
    func state(
        dueDay: Int, _ dueMonth: DueMonth = .sameMonth, in month: BillingMonth = .september,
        clock: WallClock = .testing
    ) throws -> DueState? {
        var household = try Household.open(in: InMemoryHouseholdStore(), clock: clock)
        try household.addBill(.cityPower(in: household, dueDay: dueDay, dueMonth: dueMonth))
        let board = try household.openBillingMonth(month)
        return board.state(of: try #require(board.dues.first))
    }

    @Test(
        "a Due is Overdue from the day after its Due Date and Due Soon from 7 days before it through the day itself",
        arguments: [
            (14, DueState.overdue),  // yesterday
            (15, .dueSoon),  // today
            (22, .dueSoon),  // a week away, still soon
            (23, nil),  // beyond the week
        ] as [(Int, DueState?)]
    )
    func overdueAndDueSoonBoundaries(dueDay: Int, expected: DueState?) throws {
        #expect(try state(dueDay: dueDay) == expected)
    }

    @Test("a Paid Due is neither Overdue nor Due Soon, only Paid", arguments: [14, 15])
    func aPaidDueIsOnlyPaid(dueDay: Int) throws {
        var household = try Household.open(in: InMemoryHouseholdStore(), clock: .testing)
        try household.addBill(.cityPower(in: household, dueDay: dueDay))
        try household.markPaid(try household.due(named: "City Power").id, by: "Mircea")

        let board = try household.openBillingMonth(.september)

        #expect(board.state(of: try #require(board.dues.first)) == .paid)
    }

    @Test("Edit undoes Paid, and the Due is Overdue again")
    func editMakesAPaidDueOverdueAgain() throws {
        var household = try Household.open(in: InMemoryHouseholdStore(), clock: .testing)
        try household.addBill(.cityPower(in: household, dueDay: 14))
        let due = try household.due(named: "City Power")
        try household.markPaid(due.id, by: "Mircea")

        try household.undoPaid(due.id)

        let board = try household.openBillingMonth(.september)
        #expect(board.state(of: try #require(board.dues.first)) == .overdue)
    }

    @Test("the states follow the clock, so a Due Soon becomes Overdue once its Due Date has passed")
    func theStatesFollowTheClock() throws {
        let store = InMemoryHouseholdStore()
        var household = try Household.open(in: store, clock: .testing)
        try household.addBill(.cityPower(in: household, dueDay: 15))
        let board = try household.openBillingMonth(.september)
        #expect(board.state(of: try #require(board.dues.first)) == .dueSoon)

        var nextDay = try Household.open(in: store, clock: .at("2026-09-16T12:00:00Z"))

        let later = try nextDay.openBillingMonth(.september)
        #expect(later.state(of: try #require(later.dues.first)) == .overdue)
    }

    @Test(
        "Due Soon reaches into the next month: on September 28 a Due on October 5 is Due Soon, on October 6 not",
        arguments: [(1, DueState.dueSoon), (5, .dueSoon), (6, nil)] as [(Int, DueState?)]
    )
    func dueSoonReachesIntoTheNextMonth(dueDay: Int, expected: DueState?) throws {
        let clock = WallClock.at("2026-09-28T12:00:00Z")
        #expect(try state(dueDay: dueDay, .nextMonth, clock: clock) == expected)
    }

    @Test("on October 1 a Due of September on the 28th is Overdue and one on October 1 is Due Soon")
    func overdueReachesBackIntoThePreviousMonth() throws {
        let clock = WallClock.at("2026-10-01T12:00:00Z")
        #expect(try state(dueDay: 28, clock: clock) == .overdue)
        #expect(try state(dueDay: 1, .nextMonth, clock: clock) == .dueSoon)
    }

    @Test(
        "Due Soon reaches into the next year: on December 28 a Due on January 4 is Due Soon, on January 5 not",
        arguments: [(4, DueState.dueSoon), (5, nil)] as [(Int, DueState?)]
    )
    func dueSoonReachesIntoTheNextYear(dueDay: Int, expected: DueState?) throws {
        let clock = WallClock.at("2026-12-28T12:00:00Z")
        let december = BillingMonth(year: 2026, month: 12)
        #expect(try state(dueDay: dueDay, .nextMonth, in: december, clock: clock) == expected)
    }

    @Test("today is the clock's date in its time zone: west of UTC it is still the Due Date, so Due Soon")
    func westOfUTCTheDueDateIsStillToday() throws {
        // 02:00 UTC on October 5 is still the evening of October 4 in New York.
        let clock = WallClock.at("2026-10-05T02:00:00Z")
        #expect(try state(dueDay: 4, in: .october, clock: clock) == .dueSoon)
        // A week ahead is October 11 there, not October 12 as in UTC.
        #expect(try state(dueDay: 12, in: .october, clock: clock) == nil)
    }

    @Test("today is the clock's date in its time zone: east of UTC the Due Date has already passed, so Overdue")
    func eastOfUTCTheDueDateHasPassed() throws {
        // 16:00 UTC on October 4 is already 01:00 on October 5 in Tokyo.
        let clock = WallClock.at("2026-10-04T16:00:00Z", in: "Asia/Tokyo")
        #expect(try state(dueDay: 4, in: .october, clock: clock) == .overdue)
    }
}
