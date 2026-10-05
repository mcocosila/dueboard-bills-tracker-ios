import Foundation
import Testing
import HouseholdCore

/// The reminder plan: every notification that should be pending, worked out from the Dues
/// and the clock. The web app had no reminders, so these tests have no counterpart there.
@Suite("Reminders")
struct ReminderPlanTests {
    /// The moment written as ISO 8601 in UTC.
    func moment(_ iso: String) -> Date {
        ISO8601DateFormatter().date(from: iso)!
    }

    /// A Household on `clock` with City Power due on `dueDay` of `dueMonth`, and `month` opened.
    func household(
        dueDay: Int = 25, _ dueMonth: DueMonth = .sameMonth, in month: BillingMonth = .september,
        clock: WallClock = .testing
    ) throws -> Household {
        var household = try Household.open(in: InMemoryHouseholdStore(), clock: clock)
        try household.addBill(.cityPower(in: household, dueDay: dueDay, dueMonth: dueMonth))
        _ = try household.openBillingMonth(month)
        return household
    }

    @Test("a Due not Paid is reminded at 9:00 on the day it becomes Due Soon, on its Due Date and the day after")
    func threeRemindersPerDue() throws {
        let household = try household(dueDay: 25)
        let due = try #require(household.reminderPlan.first?.dueID)

        let plan = household.reminderPlan

        // 9:00 in New York is 13:00 UTC in September.
        #expect(plan.map(\.kind) == [.dueSoon, .dueDate, .overdue])
        #expect(plan.map(\.fireDate) == [
            moment("2026-09-18T13:00:00Z"), moment("2026-09-25T13:00:00Z"), moment("2026-09-26T13:00:00Z"),
        ])
        #expect(plan.allSatisfy { $0.dueID == due && $0.billingMonth == .september })
    }

    @Test("each Reminder has a stable identifier per Due and kind, the same each time the plan is made")
    func stableIdentifiers() throws {
        let store = InMemoryHouseholdStore()
        var household = try Household.open(in: store, clock: .testing)
        try household.addBill(.cityPower(in: household, dueDay: 25))
        try household.addBill(.mortgage(in: household))
        _ = try household.openBillingMonth(.october)

        let ids = household.reminderPlan.map(\.id)
        let reopened = try Household.open(in: store, clock: .testing)
        let later = try Household.open(in: store, clock: .at("2026-10-05T12:00:00Z"))

        #expect(Set(ids).count == ids.count)
        #expect(reopened.reminderPlan.map(\.id) == ids)
        // Later, the Reminders still to come keep their identifiers.
        #expect(later.reminderPlan.map(\.id) == ids.filter { id in later.reminderPlan.contains { $0.id == id } })
        #expect(later.reminderPlan.count < ids.count)
    }

    @Test("each Reminder names its Due and says why it is sent")
    func text() throws {
        let plan = try household(dueDay: 25).reminderPlan

        #expect(plan.map(\.title) == ["City Power", "City Power", "City Power"])
        #expect(plan.map(\.body) == ["Due Soon: due in 7 days.", "Due today.", "Overdue: it was due yesterday."])
    }

    @Test("only Reminders still to come are planned: on the Due Date after 9:00 only the day after is left")
    func onlyRemindersStillToCome() throws {
        let beforeNine = try household(dueDay: 25, clock: .at("2026-09-25T12:59:00Z"))
        let atNine = try household(dueDay: 25, clock: .at("2026-09-25T13:00:00Z"))
        let dayAfterNoon = try household(dueDay: 25, clock: .at("2026-09-26T16:00:00Z"))

        #expect(beforeNine.reminderPlan.map(\.kind) == [.dueDate, .overdue])
        #expect(atNine.reminderPlan.map(\.kind) == [.overdue])
        #expect(dayAfterNoon.reminderPlan.isEmpty)
    }

    @Test("a Paid Due has no Reminders, and Edit back to not Paid restores them")
    func paidAndEdit() throws {
        var household = try household(dueDay: 25)
        let due = try household.due(named: "City Power")

        try household.markPaid(due.id, by: "Mircea")
        #expect(household.reminderPlan.isEmpty)

        try household.undoPaid(due.id)
        #expect(household.reminderPlan.map(\.kind) == [.dueSoon, .dueDate, .overdue])
    }

    @Test("a Due Paid from birth, its Default Amount zero, has no Reminders")
    func paidFromBirth() throws {
        var household = try Household.open(in: InMemoryHouseholdStore(), clock: .testing)
        try household.addBill(.homeDepot(in: household, defaultAmount: 0))
        _ = try household.openBillingMonth(.september)

        #expect(household.reminderPlan.isEmpty)
    }

    @Test("a removed Due has no Reminders")
    func removedDue() throws {
        var household = try household(dueDay: 25)

        try household.removeDue(try household.due(named: "City Power").id)

        #expect(household.reminderPlan.isEmpty)
    }

    @Test("a Retired Bill's Dues have no Reminders, and reactivating it restores them")
    func retiredBill() throws {
        var household = try household(dueDay: 25)
        let bill = try household.bill(named: "City Power")

        try household.retireBill(bill.id)
        #expect(household.reminderPlan.isEmpty)

        try household.reactivateBill(bill.id)
        #expect(household.reminderPlan.count == 3)
    }

    @Test("a Card-Paid Due is reminded like any other, since reminding is what it is tracked for")
    func cardPaid() throws {
        var household = try Household.open(in: InMemoryHouseholdStore(), clock: .testing)
        try household.addBill(.danceStudio(in: household))
        _ = try household.openBillingMonth(.october)

        #expect(household.reminderPlan.map(\.kind) == [.dueSoon, .dueDate, .overdue])
    }

    @Test("Reminders fire at 9:00 in the clock's time zone, wherever that is")
    func nineInTheClocksTimeZone() throws {
        let tokyo = try household(dueDay: 25, clock: .at("2026-09-15T03:00:00Z", in: "Asia/Tokyo"))
        let london = try household(dueDay: 25, clock: .at("2026-09-15T12:00:00Z", in: "Europe/London"))

        // 9:00 in Tokyo is 0:00 UTC; 9:00 in London in summer is 8:00 UTC.
        #expect(tokyo.reminderPlan.map(\.fireDate) == [
            moment("2026-09-18T00:00:00Z"), moment("2026-09-25T00:00:00Z"), moment("2026-09-26T00:00:00Z"),
        ])
        #expect(london.reminderPlan.map(\.fireDate) == [
            moment("2026-09-18T08:00:00Z"), moment("2026-09-25T08:00:00Z"), moment("2026-09-26T08:00:00Z"),
        ])
    }

    @Test("9:00 stays 9:00 across a change of clocks: Due Soon before it in summer time, Due Date after it in winter time")
    func acrossAChangeOfClocks() throws {
        // New York leaves summer time on November 1, 2026.
        let clock = WallClock.at("2026-10-20T12:00:00Z")
        let household = try household(dueDay: 3, .nextMonth, in: .october, clock: clock)

        #expect(household.reminderPlan.map(\.fireDate) == [
            moment("2026-10-27T13:00:00Z"), moment("2026-11-03T14:00:00Z"), moment("2026-11-04T14:00:00Z"),
        ])
    }

    @Test("Due Soon reaches back into the previous month: a Due on October 3 is Due Soon from September 26")
    func dueSoonInThePreviousMonth() throws {
        let household = try household(dueDay: 3, .nextMonth)

        #expect(household.reminderPlan.map(\.fireDate) == [
            moment("2026-09-26T13:00:00Z"), moment("2026-10-03T13:00:00Z"), moment("2026-10-04T13:00:00Z"),
        ])
        #expect(household.reminderPlan.allSatisfy { $0.billingMonth == .september })
    }

    @Test("the day after reaches into the next month: a Due on February 28, 2027 is reminded again on March 1")
    func overdueInTheNextMonth() throws {
        let clock = WallClock.at("2027-02-15T17:00:00Z")
        let february = BillingMonth(year: 2027, month: 2)

        let household = try household(dueDay: 28, in: february, clock: clock)

        // New York is on winter time: 9:00 is 14:00 UTC.
        #expect(household.reminderPlan.map(\.fireDate) == [
            moment("2027-02-21T14:00:00Z"), moment("2027-02-28T14:00:00Z"), moment("2027-03-01T14:00:00Z"),
        ])
    }

    @Test("the reminders cross the year: a Due on January 4 is Due Soon on December 28")
    func acrossTheYear() throws {
        let clock = WallClock.at("2026-12-20T17:00:00Z")
        let december = BillingMonth(year: 2026, month: 12)

        let household = try household(dueDay: 4, .nextMonth, in: december, clock: clock)

        #expect(household.reminderPlan.map(\.fireDate) == [
            moment("2026-12-28T14:00:00Z"), moment("2027-01-04T14:00:00Z"), moment("2027-01-05T14:00:00Z"),
        ])
    }

    @Test("the plan is in fire time order across Dues and Billing Months")
    func inFireTimeOrder() throws {
        var household = try Household.open(in: InMemoryHouseholdStore(), clock: .testing)
        try household.addBill(.cityPower(in: household, dueDay: 25))
        try household.addBill(.riversideSchool(in: household))
        _ = try household.openBillingMonth(.september)
        _ = try household.openBillingMonth(.october)

        let plan = household.reminderPlan

        #expect(plan.map(\.fireDate) == plan.map(\.fireDate).sorted())
        #expect(plan.count == 12)
    }

    @Test("the plan is capped at the 64 earliest Reminders, and a Due marked Paid makes room for the next")
    func cappedAt64() throws {
        var household = try Household.open(in: InMemoryHouseholdStore(), clock: .testing)
        for number in 1...11 {
            var bill = NewBill.cityPower(in: household, dueDay: 25)
            bill.name = "Bill \(number)"
            try household.addBill(bill)
        }
        _ = try household.openBillingMonth(.september)
        _ = try household.openBillingMonth(.october)
        // 11 Dues in each month, 3 Reminders each: 66, so 2 of October 26 are left out.
        let october26 = moment("2026-10-26T13:00:00Z")

        #expect(household.reminderPlan.count == Reminder.limit)
        #expect(Reminder.limit == 64)
        #expect(household.reminderPlan.count { $0.fireDate == october26 } == 9)

        try household.markPaid(try household.due(named: "Bill 1").id, by: "Mircea")

        // 63 left, so the two left out come back.
        #expect(household.reminderPlan.count == 63)
        #expect(household.reminderPlan.count { $0.fireDate == october26 } == 11)
    }
}
