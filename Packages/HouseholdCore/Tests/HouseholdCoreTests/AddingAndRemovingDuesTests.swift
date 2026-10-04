import Foundation
import Testing
import HouseholdCore

/// Mirrors the web app's tests for adding and removing Dues. The clock is `.testing`:
/// September 15, 2026 in New York.
@Suite("Adding and removing Dues")
struct AddingAndRemovingDuesTests {
    /// August 2026 opened with City Power and Mortgage, without Walmart (Occasional) and Water
    /// (Retired), and with Plumber (Occasional) added to the Bills afterwards.
    func august() throws -> Household {
        var household = try Household.open(in: InMemoryHouseholdStore(), clock: .testing)
        try household.addBill(.cityPower(in: household))
        try household.addBill(.mortgage(in: household))
        try household.addBill(.walmart(in: household))
        let water = try household.addBill(.water(in: household))
        try household.retireBill(water.id)
        _ = try household.openBillingMonth(.august)
        try household.addBill(.plumber(in: household))
        return household
    }

    @Test("a month offers to add every Bill not Retired that it has no Due for, by Category")
    func theMonthOffersEveryBillNotRetiredWithoutADue() throws {
        var household = try august()

        let toAdd = try household.openBillingMonth(.august).billsToAdd

        #expect(toAdd.map(\.category.name) == ["House", "Credit Cards"])
        #expect(toAdd.map { $0.bills.map(\.name) } == [["Plumber"], ["Walmart"]])
    }

    @Test("adding a Bill generates its Due as opening the month would, and it is no longer offered")
    func addingABillGeneratesItsDue() throws {
        var household = try august()
        let plumber = try household.bill(named: "Plumber")
        var details = NewBill(plumber)
        details.defaultAmount = Decimal(string: "250.00")
        try household.editBill(plumber.id, to: details)

        let due = try household.addDue(of: plumber.id, to: .august)

        #expect(due.categoryID == household.categories[0].id)
        #expect(due.dueDate == DueDate(year: 2026, month: 8, day: 20))
        #expect(due.amount == Decimal(string: "250.00"))
        #expect(due.paid == nil)
        let board = try household.openBillingMonth(.august)
        #expect(board.dues.contains(due))
        #expect(!board.billsToAdd.flatMap(\.bills).contains { $0.name == "Plumber" })
    }

    @Test("Unpaid Remaining counts an added Due")
    func unpaidRemainingCountsAnAddedDue() throws {
        var household = try august()
        let before = try household.openBillingMonth(.august).unpaidRemaining.amount

        try household.addDue(of: try household.bill(named: "Walmart").id, to: .august)

        let after = try household.openBillingMonth(.august).unpaidRemaining.amount
        #expect(after - before == Decimal(string: "120.00"))
    }

    @Test("a Bill with a zero Default Amount is added Paid")
    func aZeroDefaultAmountIsAddedPaid() throws {
        var household = try august()
        let walmart = try household.bill(named: "Walmart")
        var details = NewBill(walmart)
        details.defaultAmount = 0
        try household.editBill(walmart.id, to: details)

        let due = try household.addDue(of: walmart.id, to: .august)

        #expect(due.paid != nil)
    }

    @Test("a Bill added to a past month is Overdue at once")
    func aBillAddedToAPastMonthIsOverdue() throws {
        var household = try august()

        let due = try household.addDue(of: try household.bill(named: "Plumber").id, to: .august)

        #expect(try household.openBillingMonth(.august).state(of: due) == .overdue)
    }

    @Test("a Retired Bill cannot be added, and the refusal says why")
    func aRetiredBillCannotBeAdded() throws {
        var household = try august()
        let before = try household.openBillingMonth(.august).dues

        let refusal = #expect(throws: BillRefusal.retired) {
            try household.addDue(of: try household.bill(named: "Water").id, to: .august)
        }

        #expect(refusal?.localizedDescription == "A Retired Bill cannot be added; reactivate it first")
        #expect(try household.openBillingMonth(.august).dues == before)
    }

    @Test("adding a Bill already in the month changes nothing and hands back the Due it has")
    func addingABillAlreadyInTheMonthChangesNothing() throws {
        var household = try august()
        let cityPower = try household.due(named: "City Power", in: .august)
        try household.enterAmount(Decimal(string: "142.30"), on: cityPower.id, by: "Mircea")

        let again = try household.addDue(of: cityPower.billID, to: .august)

        #expect(again.id == cityPower.id)
        #expect(again.amount == Decimal(string: "142.30"))
        #expect(try household.openBillingMonth(.august).dues.filter { $0.name == "City Power" }.count == 1)
    }

    @Test("a Due not Paid is removed, and adding its Bill again generates a fresh Due")
    func aDueIsRemovedAndCanBeAddedBackFresh() throws {
        var household = try august()
        let cityPower = try household.due(named: "City Power", in: .august)
        try household.enterAmount(Decimal(string: "142.30"), on: cityPower.id, by: "Mircea")
        #expect(try household.openBillingMonth(.august).canRemove(cityPower))

        try household.removeDue(cityPower.id)

        let board = try household.openBillingMonth(.august)
        #expect(!board.dues.contains { $0.name == "City Power" })
        #expect(board.billsToAdd[0].bills.map(\.name) == ["City Power", "Plumber"])

        let fresh = try household.addDue(of: cityPower.billID, to: .august)

        #expect(fresh.id != cityPower.id)
        #expect(fresh.amount == nil)
    }

    @Test("a Paid Due cannot be removed, and the refusal says why")
    func aPaidDueCannotBeRemoved() throws {
        var household = try august()
        let mortgage = try household.due(named: "Mortgage", in: .august)
        try household.markPaid(mortgage.id, by: "Mircea")

        #expect(try household.openBillingMonth(.august).canRemove(try household.due(named: "Mortgage", in: .august)) == false)
        let refusal = #expect(throws: DueRefusal.paidNotRemovable) { try household.removeDue(mortgage.id) }

        #expect(refusal?.localizedDescription == "A Paid Due cannot be removed; press Edit first")
        #expect(try household.openBillingMonth(.august).dues.contains { $0.name == "Mortgage" })
    }

    @Test("adding a Bill to a month never opened opens it, with a Due for each Recurring Bill too")
    func addingToAMonthNeverOpenedOpensIt() throws {
        var household = try august()

        try household.addDue(of: try household.bill(named: "Plumber").id, to: .october)

        #expect(try household.openBillingMonth(.october).dues.map(\.name) == ["Mortgage", "City Power", "Plumber"])
    }

    @Test("a Bill cannot be added to a month that cannot be opened yet")
    func aBillCannotBeAddedTwoMonthsAhead() throws {
        var household = try august()

        #expect(throws: BillingMonthRefusal.tooFarAhead) {
            try household.addDue(of: try household.bill(named: "Plumber").id, to: BillingMonth(year: 2026, month: 11))
        }
    }

    @Test("a Bill that is not in the Household is refused with a readable message")
    func anUnknownBillIsRefused() throws {
        var household = try august()

        let refusal = #expect(throws: BillRefusal.noSuchBill) { try household.addDue(of: UUID(), to: .august) }

        #expect(refusal?.localizedDescription == "This Bill no longer exists")
    }

    @Test("removing a Due that is not in the Household is refused")
    func removingAnUnknownDueIsRefused() throws {
        var household = try august()

        #expect(throws: DueRefusal.noSuchDue) { try household.removeDue(UUID()) }
    }

    @Test("added and removed Dues stay that way when the Household is opened again from its store")
    func addedAndRemovedDuesSurviveReopening() throws {
        let store = InMemoryHouseholdStore()
        var household = try Household.open(in: store, clock: .testing)
        try household.addBill(.cityPower(in: household))
        let plumber = try household.addBill(.plumber(in: household))
        try household.removeDue(try household.due(named: "City Power", in: .august).id)
        try household.addDue(of: plumber.id, to: .august)
        try household.addDue(of: plumber.id, to: .october)

        var reopened = try Household.open(in: store, clock: .testing)

        #expect(try reopened.openBillingMonth(.august).dues.map(\.name) == ["Plumber"])
        #expect(try reopened.openBillingMonth(.october).dues.map(\.name) == ["City Power", "Plumber"])
    }
}
