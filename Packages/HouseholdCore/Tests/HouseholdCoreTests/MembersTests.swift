import Foundation
import Testing
import HouseholdCore

/// Two Members of one Household, each on their own device: both open the Household from the
/// same store, the way iCloud hands each device the same records.
@Suite("Members sharing a Household")
struct MembersTests {
    @Test("a Due marked Paid by one Member shows as Paid on the other Member's device, with who and when")
    func paidByOneMemberShowsOnTheOther() throws {
        let store = InMemoryHouseholdStore()
        var owner = try Household.open(in: store, clock: .testing)
        try owner.addBill(.cityPower(in: owner))
        let due = try owner.due(named: "City Power")
        let paidAt = WallClock.at("2026-09-16T13:30:00Z")
        var partner = try Household.open(in: store, clock: paidAt)

        try partner.markPaid(due.id, by: "Cristina Popescu")

        var ownerAgain = try Household.open(in: store, clock: .testing)
        let paid = try #require(try ownerAgain.due(named: "City Power").paid)
        #expect(paid.by == "Cristina Popescu")
        #expect(paid.at == paidAt.now)
    }

    @Test("a Due Edited by one Member and marked Paid again by the other records the other")
    func paidAgainByTheOtherMemberRecordsThem() throws {
        let store = InMemoryHouseholdStore()
        var owner = try Household.open(in: store, clock: .testing)
        try owner.addBill(.cityPower(in: owner))
        let due = try owner.due(named: "City Power")
        try owner.markPaid(due.id, by: "Mircea Ionescu")
        var partner = try Household.open(in: store, clock: .testing)

        try partner.undoPaid(due.id)
        try partner.markPaid(due.id, by: "Cristina Popescu")

        var ownerAgain = try Household.open(in: store, clock: .testing)
        #expect(try ownerAgain.due(named: "City Power").paid?.by == "Cristina Popescu")
    }

    @Test("a Member whose device has no Household yet opens the one already in the store, not a new one")
    func aMemberOpensTheHouseholdAlreadyThere() throws {
        let store = InMemoryHouseholdStore()
        var owner = try Household.open(in: store, clock: .testing)
        try owner.addCategory(named: "Car")
        try owner.addBill(.cityPower(in: owner))

        var partner = try Household.open(in: store, clock: .testing)

        #expect(partner.categories.map(\.name) == owner.categories.map(\.name))
        #expect(try partner.openBillingMonth(partner.currentBillingMonth).dues.map(\.name) == ["City Power"])
    }
}
