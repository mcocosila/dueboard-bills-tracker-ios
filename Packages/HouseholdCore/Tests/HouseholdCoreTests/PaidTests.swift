import Foundation
import Testing
import HouseholdCore

/// The clock is `.testing`: September 15, 2026 in New York.
@Suite("Paid and the Amount of a Due")
struct PaidTests {
    @Test("marking Paid records when and by whom")
    func markingPaidRecordsWhenAndByWhom() throws {
        var household = try Household.open(in: InMemoryHouseholdStore(), clock: .testing)
        try household.addBill(.cityPower(in: household))
        let due = try household.due(named: "City Power")

        try household.markPaid(due.id, by: "Mircea")

        let paid = try #require(try household.due(named: "City Power").paid)
        #expect(paid.by == "Mircea")
        #expect(paid.at == WallClock.testing.now)
    }

    @Test("Edit undoes Paid, taking away when and by whom")
    func editUndoesPaid() throws {
        var household = try Household.open(in: InMemoryHouseholdStore(), clock: .testing)
        try household.addBill(.cityPower(in: household))
        let due = try household.due(named: "City Power")
        try household.markPaid(due.id, by: "Mircea")

        try household.undoPaid(due.id)

        #expect(try household.due(named: "City Power").paid == nil)
    }

    @Test("the Amount of a Paid Due cannot be changed until Edit, and the refusal says why")
    func theAmountOfAPaidDueIsLockedUntilEdit() throws {
        var household = try Household.open(in: InMemoryHouseholdStore(), clock: .testing)
        try household.addBill(.cityPower(in: household))
        let due = try household.due(named: "City Power")
        #expect(due.amount == nil)
        try household.enterAmount(Decimal(string: "123.45"), on: due.id, by: "Mircea")
        try household.markPaid(due.id, by: "Mircea")

        let refusal = #expect(throws: DueRefusal.paidNotEditable) {
            try household.enterAmount(Decimal(string: "130.00"), on: due.id, by: "Mircea")
        }
        #expect(refusal?.localizedDescription == "The Amount of a Paid Due cannot be changed; press Edit first")
        #expect(try household.due(named: "City Power").amount == Decimal(string: "123.45"))

        try household.undoPaid(due.id)
        try household.enterAmount(Decimal(string: "130.00"), on: due.id, by: "Mircea")
        let edited = try household.due(named: "City Power")
        #expect(edited.amount == Decimal(string: "130.00"))
        #expect(edited.paid == nil)
    }

    @Test("an Amount of zero marks the Due Paid by whoever entered it")
    func aZeroAmountMarksTheDuePaid() throws {
        var household = try Household.open(in: InMemoryHouseholdStore(), clock: .testing)
        try household.addBill(.cityPower(in: household))
        let due = try household.due(named: "City Power")

        try household.enterAmount(0, on: due.id, by: "Mircea")

        let paid = try #require(try household.due(named: "City Power").paid)
        #expect(paid.by == "Mircea")
        #expect(paid.at == WallClock.testing.now)
    }

    @Test("a zero Amount needs Edit before a real Amount can be entered")
    func aZeroAmountNeedsEditBeforeARealAmount() throws {
        var household = try Household.open(in: InMemoryHouseholdStore(), clock: .testing)
        try household.addBill(.cityPower(in: household))
        let due = try household.due(named: "City Power")
        try household.enterAmount(0, on: due.id, by: "Mircea")

        #expect(throws: DueRefusal.paidNotEditable) {
            try household.enterAmount(Decimal(string: "45.00"), on: due.id, by: "Mircea")
        }

        try household.undoPaid(due.id)
        try household.enterAmount(Decimal(string: "45.00"), on: due.id, by: "Mircea")
        let edited = try household.due(named: "City Power")
        #expect(edited.amount == Decimal(string: "45.00"))
        #expect(edited.paid == nil)
    }

    @Test("a Due whose Default Amount is zero is Paid from birth, by nobody, and needs Edit before a real Amount")
    func aZeroDefaultAmountIsPaidFromBirth() throws {
        var household = try Household.open(in: InMemoryHouseholdStore(), clock: .testing)
        try household.addBill(.homeDepot(in: household, defaultAmount: 0))

        let due = try household.due(named: "Home Depot")
        let paid = try #require(due.paid)
        #expect(paid.by == nil)
        #expect(throws: DueRefusal.paidNotEditable) {
            try household.enterAmount(Decimal(string: "45.00"), on: due.id, by: "Mircea")
        }

        try household.undoPaid(due.id)
        try household.enterAmount(Decimal(string: "45.00"), on: due.id, by: "Mircea")
        #expect(try household.due(named: "Home Depot").amount == Decimal(string: "45.00"))
    }

    @Test("a zero Amount on a Due already Paid is refused and keeps who Paid it and when")
    func aZeroAmountOnAPaidDueKeepsThePaidRecord() throws {
        var household = try Household.open(in: InMemoryHouseholdStore(), clock: .testing)
        try household.addBill(.cityPower(in: household))
        let due = try household.due(named: "City Power")
        try household.markPaid(due.id, by: "Cristina")
        let paid = try household.due(named: "City Power").paid

        #expect(throws: DueRefusal.paidNotEditable) {
            try household.enterAmount(0, on: due.id, by: "Mircea")
        }

        let kept = try household.due(named: "City Power")
        #expect(kept.amount == nil)
        #expect(kept.paid == paid)
    }

    @Test("marking a Paid Due Paid again keeps who first marked it and when")
    func markingAPaidDuePaidAgainKeepsTheFirstRecord() throws {
        var household = try Household.open(in: InMemoryHouseholdStore(), clock: .testing)
        try household.addBill(.cityPower(in: household))
        let due = try household.due(named: "City Power")
        try household.markPaid(due.id, by: "Cristina")

        try household.markPaid(due.id, by: "Mircea")

        #expect(try household.due(named: "City Power").paid?.by == "Cristina")
    }

    @Test("entering a Due's Amount never changes the Bill's Default Amount, so later months still pre-fill it")
    func enteringAnAmountLeavesTheDefaultAmountAlone() throws {
        var household = try Household.open(in: InMemoryHouseholdStore(), clock: .testing)
        let mortgage = try household.addBill(.mortgage(in: household))
        let due = try household.due(named: "Mortgage")

        try household.enterAmount(Decimal(string: "3600.00"), on: due.id, by: "Mircea")

        #expect(household.billsList.groups[0].bills.first { $0.id == mortgage.id }?.defaultAmount == Decimal(string: "3500.00"))
        #expect(try household.due(named: "Mortgage", in: .october).amount == Decimal(string: "3500.00"))
    }

    @Test("an Amount can be cleared while the Due is not Paid")
    func anAmountCanBeCleared() throws {
        var household = try Household.open(in: InMemoryHouseholdStore(), clock: .testing)
        try household.addBill(.mortgage(in: household))
        let due = try household.due(named: "Mortgage")

        try household.enterAmount(nil, on: due.id, by: "Mircea")

        #expect(try household.due(named: "Mortgage").amount == nil)
    }

    @Test("a negative Amount is refused with a readable message and the Amount is kept")
    func aNegativeAmountIsRefused() throws {
        var household = try Household.open(in: InMemoryHouseholdStore(), clock: .testing)
        try household.addBill(.cityPower(in: household))
        let due = try household.due(named: "City Power")

        let refusal = #expect(throws: DueRefusal.negativeAmount) {
            try household.enterAmount(-1, on: due.id, by: "Mircea")
        }

        #expect(refusal?.localizedDescription == "Amount must be 0 or more")
        #expect(try household.due(named: "City Power").amount == nil)
    }

    @Test("a Due that is not in the Household is refused with a readable message")
    func anUnknownDueIsRefused() throws {
        var household = try Household.open(in: InMemoryHouseholdStore(), clock: .testing)

        let refusal = #expect(throws: DueRefusal.noSuchDue) { try household.markPaid(UUID(), by: "Mircea") }

        #expect(refusal?.localizedDescription == "This Due is no longer in its Billing Month")
    }

    @Test("Amounts and Paid are still there when the Household is opened again from its store")
    func amountsAndPaidSurviveReopening() throws {
        let store = InMemoryHouseholdStore()
        var household = try Household.open(in: store, clock: .testing)
        try household.addBill(.cityPower(in: household))
        try household.addBill(.mortgage(in: household))
        try household.enterAmount(Decimal(string: "89.99"), on: try household.due(named: "City Power").id, by: "Mircea")
        try household.markPaid(try household.due(named: "Mortgage").id, by: "Mircea")
        let before = try household.openBillingMonth(.september).dues

        var reopened = try Household.open(in: store, clock: .testing)

        #expect(try reopened.openBillingMonth(.september).dues == before)
    }
}
