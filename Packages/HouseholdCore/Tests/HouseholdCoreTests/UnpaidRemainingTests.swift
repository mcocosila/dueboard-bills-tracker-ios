import Foundation
import Testing
import HouseholdCore

@Suite("Unpaid Remaining")
struct UnpaidRemainingTests {
    /// September 2026 with Mortgage 3500.00, Riverside School 450.00, and City Power and
    /// Home Depot with no Amount.
    func september() throws -> Household {
        var household = try Household.open(in: InMemoryHouseholdStore(), clock: .testing)
        try household.addBill(.mortgage(in: household))
        try household.addBill(.riversideSchool(in: household))
        try household.addBill(.cityPower(in: household))
        try household.addBill(.homeDepot(in: household, defaultAmount: nil))
        return household
    }

    @Test("Unpaid Remaining sums the Amounts of the Dues not Paid and counts those without an Amount")
    func unpaidRemainingSumsUnpaidAmounts() throws {
        var household = try september()

        let remaining = try household.openBillingMonth(.september).unpaidRemaining

        #expect(remaining == UnpaidRemaining(amount: Decimal(string: "3950.00")!, withoutAmount: 2))
    }

    @Test("marking Paid takes the Due out of Unpaid Remaining")
    func markingPaidTakesTheDueOut() throws {
        var household = try september()
        try household.markPaid(try household.due(named: "Mortgage").id, by: "Mircea")
        try household.markPaid(try household.due(named: "City Power").id, by: "Mircea")

        let remaining = try household.openBillingMonth(.september).unpaidRemaining

        #expect(remaining == UnpaidRemaining(amount: Decimal(string: "450.00")!, withoutAmount: 1))
    }

    @Test("an Amount entered on a Due not Paid is counted in Unpaid Remaining")
    func anEnteredAmountIsCounted() throws {
        var household = try september()
        try household.enterAmount(Decimal(string: "89.99"), on: try household.due(named: "City Power").id, by: "Mircea")

        let remaining = try household.openBillingMonth(.september).unpaidRemaining

        #expect(remaining == UnpaidRemaining(amount: Decimal(string: "4039.99")!, withoutAmount: 1))
    }

    @Test("Unpaid Remaining is zero when every Due is Paid")
    func unpaidRemainingIsZeroWhenEverythingIsPaid() throws {
        var household = try september()
        for due in try household.openBillingMonth(.september).dues {
            try household.markPaid(due.id, by: "Mircea")
        }

        let remaining = try household.openBillingMonth(.september).unpaidRemaining

        #expect(remaining == UnpaidRemaining(amount: 0, withoutAmount: 0))
    }

    @Test("Unpaid Remaining counts only its own Billing Month")
    func unpaidRemainingCountsOnlyItsOwnMonth() throws {
        var household = try september()
        _ = try household.openBillingMonth(.september)
        try household.markPaid(try household.due(named: "Mortgage", in: .october).id, by: "Mircea")

        let remaining = try household.openBillingMonth(.september).unpaidRemaining

        #expect(remaining == UnpaidRemaining(amount: Decimal(string: "3950.00")!, withoutAmount: 2))
    }
}
