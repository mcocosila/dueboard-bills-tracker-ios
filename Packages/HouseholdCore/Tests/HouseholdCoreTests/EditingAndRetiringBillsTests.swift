import Foundation
import Testing
import HouseholdCore

/// Mirrors the web app's tests for the Bills page: editing, Retiring and reactivating a Bill.
/// The clock is `.testing`: September 15, 2026 in New York.
@Suite("Editing and Retiring Bills")
struct EditingAndRetiringBillsTests {
    @Test("a Bill is edited, and the Dues it already has keep what they were generated with")
    func aBillIsEdited() throws {
        var household = try Household.open(in: InMemoryHouseholdStore(), clock: .testing)
        let cityPower = try household.addBill(NewBill(
            name: "City Power", categoryID: household.categories[0].id, dueDay: 17, dueMonth: .sameMonth,
            defaultAmount: Decimal(string: "89.99")
        ))
        let july = try household.openBillingMonth(.july).dues

        let edited = try household.editBill(cityPower.id, to: NewBill(
            name: "  City Power Electric ", categoryID: household.categories[1].id, dueDay: 18, dueMonth: .nextMonth,
            defaultAmount: nil
        ))

        #expect(edited.name == "City Power Electric")
        #expect(edited.categoryID == household.categories[1].id)
        #expect(edited.dueDay == DueDay(day: 18, month: .nextMonth))
        #expect(edited.defaultAmount == nil)
        #expect(edited.position == cityPower.position)
        #expect(try household.bill(named: "City Power Electric") == edited)
        #expect(try household.openBillingMonth(.july).dues == july)
        let august = try household.due(named: "City Power Electric", in: .august)
        #expect(august.dueDate == DueDate(year: 2026, month: 9, day: 18))
        #expect(august.categoryID == household.categories[1].id)
    }

    @Test("an edit that breaks a rule is refused with a readable message and the Bill is kept as it was")
    func anEditThatBreaksARuleIsRefused() throws {
        var household = try Household.open(in: InMemoryHouseholdStore(), clock: .testing)
        let cityPower = try household.addBill(.cityPower(in: household))
        var details = NewBill(cityPower)
        details.dueDay = 29

        let refusal = #expect(throws: BillRefusal.self) { try household.editBill(cityPower.id, to: details) }

        #expect(refusal?.localizedDescription == "Day must be 1 to 28")
        #expect(try household.bill(named: "City Power") == cityPower)
    }

    @Test("editing a Bill that is not in the Household is refused")
    func editingAnUnknownBillIsRefused() throws {
        var household = try Household.open(in: InMemoryHouseholdStore(), clock: .testing)

        #expect(throws: BillRefusal.noSuchBill) { try household.editBill(UUID(), to: .cityPower(in: household)) }
    }

    @Test("a new Default Amount leaves existing Dues alone and pre-fills later ones")
    func aNewDefaultAmountPrefillsOnlyLaterDues() throws {
        var household = try Household.open(in: InMemoryHouseholdStore(), clock: .testing)
        let mortgage = try household.addBill(.mortgage(in: household))
        _ = try household.openBillingMonth(.july)
        var details = NewBill(mortgage)
        details.defaultAmount = Decimal(string: "3600.00")

        try household.editBill(mortgage.id, to: details)

        #expect(try household.due(named: "Mortgage", in: .july).amount == Decimal(string: "3500.00"))
        #expect(try household.due(named: "Mortgage", in: .august).amount == Decimal(string: "3600.00"))
    }

    @Test("a Retired Bill keeps its earlier Dues and gets none in months opened afterwards")
    func aRetiredBillKeepsItsEarlierDues() throws {
        var household = try Household.open(in: InMemoryHouseholdStore(), clock: .testing)
        try household.addBill(.mortgage(in: household))
        let walmart = try household.addBill(.walmart(in: household, recurring: true))
        _ = try household.openBillingMonth(.july)

        let retired = try household.retireBill(walmart.id)

        #expect(retired.isRetired)
        #expect(try household.openBillingMonth(.july).dues.map(\.name) == ["Mortgage", "Walmart"])
        #expect(try household.openBillingMonth(.august).dues.map(\.name) == ["Mortgage"])
    }

    @Test("Retired Bills are listed apart after the Categories, and the Category counts leave them out")
    func retiredBillsAreListedApart() throws {
        var household = try Household.open(in: InMemoryHouseholdStore(), clock: .testing)
        try household.addBill(.cityPower(in: household))
        let water = try household.addBill(.water(in: household))
        let walmart = try household.addBill(.walmart(in: household))
        try household.addBill(.homeDepot(in: household, defaultAmount: nil))

        try household.retireBill(walmart.id)
        try household.retireBill(water.id)

        let list = household.billsList
        #expect(list.groups.map { $0.bills.map(\.name) } == [["City Power"], [], ["Home Depot"]])
        #expect(list.groups.map(\.count) == [1, 0, 1])
        #expect(list.retired.map(\.name) == ["Water", "Walmart"])
    }

    @Test("reactivating resumes generation for months opened afterwards, not for months already opened")
    func reactivatingResumesGenerationAfterwards() throws {
        var household = try Household.open(in: InMemoryHouseholdStore(), clock: .testing)
        try household.addBill(.mortgage(in: household))
        let walmart = try household.addBill(.walmart(in: household, recurring: true))
        try household.retireBill(walmart.id)
        _ = try household.openBillingMonth(.july)

        let reactivated = try household.reactivateBill(walmart.id)

        #expect(!reactivated.isRetired)
        #expect(try household.openBillingMonth(.july).dues.map(\.name) == ["Mortgage"])
        #expect(try household.openBillingMonth(.august).dues.map(\.name) == ["Mortgage", "Walmart"])
        #expect(household.billsList.retired.isEmpty)
        #expect(household.billsList.groups[2].bills.map(\.name) == ["Walmart"])
    }

    @Test("Retiring or reactivating a Bill that is not in the Household is refused")
    func retiringAnUnknownBillIsRefused() throws {
        var household = try Household.open(in: InMemoryHouseholdStore(), clock: .testing)

        #expect(throws: BillRefusal.noSuchBill) { try household.retireBill(UUID()) }
        #expect(throws: BillRefusal.noSuchBill) { try household.reactivateBill(UUID()) }
    }

    @Test("edits and Retired are still there when the Household is opened again from its store")
    func editsAndRetiredSurviveReopening() throws {
        let store = InMemoryHouseholdStore()
        var household = try Household.open(in: store, clock: .testing)
        let mortgage = try household.addBill(.mortgage(in: household))
        let walmart = try household.addBill(.walmart(in: household))
        var details = NewBill(mortgage)
        details.defaultAmount = Decimal(string: "3600.00")
        details.isRecurring = false
        try household.editBill(mortgage.id, to: details)
        try household.retireBill(walmart.id)

        let reopened = try Household.open(in: store, clock: .testing)

        #expect(reopened.billsList.groups.map(\.bills) == household.billsList.groups.map(\.bills))
        #expect(reopened.billsList.retired == household.billsList.retired)
    }
}
