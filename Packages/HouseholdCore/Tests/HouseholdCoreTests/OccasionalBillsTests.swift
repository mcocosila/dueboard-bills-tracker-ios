import Foundation
import Testing
import HouseholdCore

/// Mirrors the web app's tests for Occasional Bills. The clock is `.testing`: September 15, 2026 in New York.
@Suite("Occasional Bills")
struct OccasionalBillsTests {
    @Test("opening a month generates no Due for an Occasional Bill")
    func openingAMonthGeneratesNoDueForAnOccasionalBill() throws {
        var household = try Household.open(in: InMemoryHouseholdStore(), clock: .testing)
        try household.addBill(.cityPower(in: household))
        try household.addBill(.plumber(in: household))

        let board = try household.openBillingMonth(.august)

        #expect(board.dues.map(\.name) == ["City Power"])
    }

    @Test("a new Bill is Recurring unless it is added as Occasional")
    func aNewBillIsRecurringUnlessAddedAsOccasional() throws {
        var household = try Household.open(in: InMemoryHouseholdStore(), clock: .testing)

        let cityPower = try household.addBill(.cityPower(in: household))
        let plumber = try household.addBill(.plumber(in: household))

        #expect(cityPower.isRecurring)
        #expect(!plumber.isRecurring)
    }

    @Test("an Occasional Bill is listed in its Category on the Bills list, marked Occasional")
    func anOccasionalBillIsListedInItsCategory() throws {
        var household = try Household.open(in: InMemoryHouseholdStore(), clock: .testing)
        try household.addBill(.cityPower(in: household))
        try household.addBill(.plumber(in: household))

        let house = household.billsList.groups[0]

        #expect(house.bills.map(\.name) == ["City Power", "Plumber"])
        #expect(house.bills.map(\.isRecurring) == [true, false])
    }

    @Test("switching a Bill between Recurring and Occasional leaves months already opened alone")
    func switchingLeavesOpenedMonthsAlone() throws {
        var household = try Household.open(in: InMemoryHouseholdStore(), clock: .testing)
        let cityPower = try household.addBill(.cityPower(in: household))
        let plumber = try household.addBill(.plumber(in: household))
        _ = try household.openBillingMonth(.august)

        var occasional = NewBill(cityPower)
        occasional.isRecurring = false
        try household.editBill(cityPower.id, to: occasional)
        var recurring = NewBill(plumber)
        recurring.isRecurring = true
        try household.editBill(plumber.id, to: recurring)

        #expect(try household.openBillingMonth(.august).dues.map(\.name) == ["City Power"])
        #expect(try household.openBillingMonth(.september).dues.map(\.name) == ["Plumber"])
    }

    @Test("a month is not opened while it has only Occasional Bills, so a Recurring Bill added afterwards gets its Due")
    func onlyOccasionalBillsLeaveTheMonthUnopened() throws {
        var household = try Household.open(in: InMemoryHouseholdStore(), clock: .testing)
        try household.addBill(.plumber(in: household))
        _ = try household.openBillingMonth(.september)

        try household.addBill(.cityPower(in: household))

        #expect(try household.openBillingMonth(.september).dues.map(\.name) == ["City Power"])
    }
}
