import Foundation
import Testing
import HouseholdCore

@Suite("Bills")
struct BillsTests {
    @Test("a new Household starts with the suggested Categories House, Education and Credit Cards")
    func newHouseholdHasTheSuggestedCategories() throws {
        let household = try Household.open(in: InMemoryHouseholdStore(), clock: .testing)

        #expect(household.categories.map(\.name) == ["House", "Education", "Credit Cards"])
    }

    @Test("a Bill is added with a name, a Category, a Due Day and a Default Amount, and is Recurring")
    func billIsAdded() throws {
        var household = try Household.open(in: InMemoryHouseholdStore(), clock: .testing)
        let house = household.categories[0]

        try household.addBill(NewBill(
            name: "City Power", categoryID: house.id, dueDay: 17, dueMonth: .sameMonth, defaultAmount: Decimal(string: "89.99")
        ))

        let bill = try #require(household.billsList.groups.first?.bills.first)
        #expect(bill.name == "City Power")
        #expect(bill.categoryID == house.id)
        #expect(bill.dueDay == DueDay(day: 17, month: .sameMonth))
        #expect(bill.defaultAmount == Decimal(string: "89.99"))
        #expect(bill.isRecurring)
    }

    @Test("a Due Day outside 1 to 28 is refused with a readable message and nothing is added", arguments: [0, 29, 31])
    func dueDayOutsideTheBoundsIsRefused(day: Int) throws {
        var household = try Household.open(in: InMemoryHouseholdStore(), clock: .testing)

        let refusal = #expect(throws: BillRefusal.self) {
            try household.addBill(.cityPower(in: household, dueDay: day))
        }

        #expect(refusal?.localizedDescription == "Day must be 1 to 28")
        #expect(household.billsList.groups.allSatisfy { $0.bills.isEmpty })
    }

    @Test("a Due Day at the bounds is accepted", arguments: [1, 28])
    func dueDayAtTheBoundsIsAccepted(day: Int) throws {
        var household = try Household.open(in: InMemoryHouseholdStore(), clock: .testing)

        try household.addBill(.cityPower(in: household, dueDay: day))

        #expect(household.billsList.groups[0].bills.map(\.dueDay.day) == [day])
    }

    @Test("Bills and Categories are still there when the Household is opened again from its store")
    func billsSurviveReopening() throws {
        let store = InMemoryHouseholdStore()
        var household = try Household.open(in: store, clock: .testing)
        try household.addBill(.cityPower(in: household))
        try household.addBill(NewBill(
            name: "Riverside School", categoryID: household.categories[1].id, dueDay: 1, dueMonth: .nextMonth,
            defaultAmount: Decimal(string: "450.00")
        ))

        let reopened = try Household.open(in: store, clock: .testing)

        #expect(reopened.categories == household.categories)
        #expect(reopened.billsList.groups.map(\.bills) == household.billsList.groups.map(\.bills))
        #expect(reopened.billsList.groups.map(\.count) == [1, 1, 0])
    }

    @Test("a Bill with no name is refused with a readable message", arguments: ["", "   "])
    func billWithNoNameIsRefused(name: String) throws {
        var household = try Household.open(in: InMemoryHouseholdStore(), clock: .testing)
        var bill = NewBill.cityPower(in: household)
        bill.name = name

        let refusal = #expect(throws: BillRefusal.self) { try household.addBill(bill) }

        #expect(refusal?.localizedDescription == "Enter a name")
        #expect(household.billsList.groups.allSatisfy { $0.bills.isEmpty })
    }

    @Test("the Bills list groups Bills by Category in Category order, each new Bill last in its Category, with a count")
    func billsListGroupsByCategory() throws {
        var household = try Household.open(in: InMemoryHouseholdStore(), clock: .testing)
        let house = household.categories[0], cards = household.categories[2]
        for (name, category) in [("Visa", cards), ("Mortgage", house), ("City Power", house), ("Store Card", cards)] {
            try household.addBill(NewBill(
                name: name, categoryID: category.id, dueDay: 10, dueMonth: .sameMonth, defaultAmount: nil
            ))
        }

        let groups = household.billsList.groups

        #expect(groups.map(\.category.name) == ["House", "Education", "Credit Cards"])
        #expect(groups.map { $0.bills.map(\.name) } == [["Mortgage", "City Power"], [], ["Visa", "Store Card"]])
        #expect(groups.map(\.count) == [2, 0, 2])
    }
}

extension NewBill {
    /// City Power in the Household's first Category, with no Default Amount.
    static func cityPower(in household: Household, dueDay: Int = 17) -> NewBill {
        NewBill(
            name: "City Power", categoryID: household.categories[0].id, dueDay: dueDay, dueMonth: .sameMonth,
            defaultAmount: nil
        )
    }
}

extension WallClock {
    /// Noon on September 15, 2026 in New York.
    static var testing: WallClock {
        .fixed(Date(timeIntervalSince1970: 1_789_488_000), in: TimeZone(identifier: "America/New_York")!)
    }
}
