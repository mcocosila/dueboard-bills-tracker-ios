import Foundation
import Testing
import HouseholdCore

@Suite("Opening a Billing Month")
struct OpeningAMonthTests {
    @Test("a Same Month Due Day falls in the Billing Month")
    func sameMonthDueDayFallsInTheBillingMonth() throws {
        var household = try Household.open(in: InMemoryHouseholdStore(), clock: .testing)
        try household.addBill(.cityPower(in: household, dueDay: 17))

        let board = try household.openBillingMonth(BillingMonth(year: 2026, month: 8))

        #expect(board.dues.map(\.dueDate) == [DueDate(year: 2026, month: 8, day: 17)])
    }

    @Test("a Next Month Due Day falls in the month after the Billing Month")
    func nextMonthDueDayFallsInTheFollowingMonth() throws {
        var household = try Household.open(in: InMemoryHouseholdStore(), clock: .testing)
        try household.addBill(.riversideSchool(in: household))

        let board = try household.openBillingMonth(BillingMonth(year: 2026, month: 8))

        #expect(board.dues.map(\.dueDate) == [DueDate(year: 2026, month: 9, day: 1)])
    }

    @Test("a Next Month Due Day in December rolls into January of the next year")
    func nextMonthDueDayInDecemberRollsIntoJanuary() throws {
        var household = try Household.open(in: InMemoryHouseholdStore(), clock: .testing)
        try household.addBill(NewBill(
            name: "Visa", categoryID: household.categories[2].id, dueDay: 10, dueMonth: .nextMonth, defaultAmount: nil
        ))

        let board = try household.openBillingMonth(BillingMonth(year: 2025, month: 12))

        #expect(board.dues.map(\.dueDate) == [DueDate(year: 2026, month: 1, day: 10)])
    }

    @Test("a Due's Amount is pre-filled from the Default Amount, or empty when the Bill has none")
    func duesArePrefilledFromDefaultAmounts() throws {
        var household = try Household.open(in: InMemoryHouseholdStore(), clock: .testing)
        try household.addBill(.riversideSchool(in: household))
        try household.addBill(.cityPower(in: household))

        let board = try household.openBillingMonth(BillingMonth(year: 2026, month: 9))

        let amounts = Dictionary(uniqueKeysWithValues: board.dues.map { ($0.name, $0.amount) })
        #expect(amounts == ["Riverside School": Decimal(string: "450.00"), "City Power": nil])
    }

    @Test("opening a month generates one Due per Recurring Bill, and opening it again generates nothing new")
    func openingAMonthGeneratesDuesOnce() throws {
        var household = try Household.open(in: InMemoryHouseholdStore(), clock: .testing)
        try household.addBill(.cityPower(in: household))
        try household.addBill(.riversideSchool(in: household))
        let september = BillingMonth(year: 2026, month: 9)

        let first = try household.openBillingMonth(september)
        try household.addBill(NewBill(
            name: "Mortgage", categoryID: household.categories[0].id, dueDay: 10, dueMonth: .sameMonth,
            defaultAmount: nil
        ))
        let again = try household.openBillingMonth(september)

        #expect(first.dues.map(\.name).sorted() == ["City Power", "Riverside School"])
        #expect(again.dues == first.dues)
    }

    @Test("an opened month keeps its Dues when the Household is opened again from its store")
    func openedMonthSurvivesReopening() throws {
        let store = InMemoryHouseholdStore()
        var household = try Household.open(in: store, clock: .testing)
        try household.addBill(.cityPower(in: household))
        let september = BillingMonth(year: 2026, month: 9)
        let opened = try household.openBillingMonth(september)

        var reopened = try Household.open(in: store, clock: .testing)
        try reopened.addBill(.riversideSchool(in: reopened))

        #expect(try reopened.openBillingMonth(september).dues == opened.dues)
    }

    @Test("a month is not opened while there are no Recurring Bills, so Bills added afterwards still get their Dues")
    func aMonthWithNoBillsStaysUnopened() throws {
        var household = try Household.open(in: InMemoryHouseholdStore(), clock: .testing)
        let september = BillingMonth(year: 2026, month: 9)

        let empty = try household.openBillingMonth(september)
        try household.addBill(.cityPower(in: household))
        let opened = try household.openBillingMonth(september)

        #expect(empty.groups.isEmpty)
        #expect(opened.dues.map(\.name) == ["City Power"])
    }

    @Test("Dues are grouped by Category in Category order, by Due Date within each, the Bill order breaking a tie")
    func duesAreGroupedByCategory() throws {
        var household = try Household.open(in: InMemoryHouseholdStore(), clock: .testing)
        let house = household.categories[0], cards = household.categories[2]
        for (name, category, day) in [
            ("Visa", cards, 20), ("City Power", house, 17), ("Mortgage", house, 10), ("Water", house, 10),
            ("Store Card", cards, 5),
        ] {
            try household.addBill(NewBill(
                name: name, categoryID: category.id, dueDay: day, dueMonth: .sameMonth, defaultAmount: nil
            ))
        }

        let groups = try household.openBillingMonth(BillingMonth(year: 2026, month: 9)).groups

        #expect(groups.map(\.category.name) == ["House", "Credit Cards"])
        #expect(groups.map { $0.dues.map(\.name) } == [["Mortgage", "Water", "City Power"], ["Store Card", "Visa"]])
    }
}

extension NewBill {
    /// Riverside School in the Household's second Category: paid in one month, due on the 1st of the next,
    /// with a Default Amount of 450.00.
    static func riversideSchool(in household: Household) -> NewBill {
        NewBill(
            name: "Riverside School", categoryID: household.categories[1].id, dueDay: 1, dueMonth: .nextMonth,
            defaultAmount: Decimal(string: "450.00")
        )
    }
}
