import Foundation
import Testing
import HouseholdCore

/// Creating, renaming, reordering and deleting the Household's Categories.
/// The clock is `.testing`: September 15, 2026 in New York.
@Suite("Categories")
struct CategoriesTests {
    @Test("a Category is created last in the order, and is still there when the Household is opened again")
    func aCategoryIsCreated() throws {
        let store = InMemoryHouseholdStore()
        var household = try Household.open(in: store, clock: .testing)

        let utilities = try household.addCategory(named: "  Utilities ")

        #expect(utilities.name == "Utilities")
        #expect(household.categories.map(\.name) == ["House", "Education", "Credit Cards", "Utilities"])
        #expect(household.billsList.groups.map(\.category.name) == ["House", "Education", "Credit Cards", "Utilities"])
        let reopened = try Household.open(in: store, clock: .testing)
        #expect(reopened.categories == household.categories)
    }

    @Test("a Category with no name is refused with a readable message", arguments: ["", "   "])
    func aCategoryWithNoNameIsRefused(name: String) throws {
        var household = try Household.open(in: InMemoryHouseholdStore(), clock: .testing)

        let refusal = #expect(throws: CategoryRefusal.self) { try household.addCategory(named: name) }

        #expect(refusal?.localizedDescription == "Enter a name")
        #expect(household.categories.map(\.name) == ["House", "Education", "Credit Cards"])
    }

    @Test("a Category named like another one in the Household is refused, whatever the case and spaces",
          arguments: ["House", "house", " HOUSE "])
    func categoryNamesAreUnique(name: String) throws {
        var household = try Household.open(in: InMemoryHouseholdStore(), clock: .testing)

        let refusal = #expect(throws: CategoryRefusal.self) { try household.addCategory(named: name) }

        #expect(refusal?.localizedDescription == "There is already a Category named House")
        #expect(household.categories.map(\.name) == ["House", "Education", "Credit Cards"])
    }

    @Test("a renamed Category keeps its Bills and Dues, and the Bills list and the Billing Month show the new name")
    func aCategoryIsRenamed() throws {
        let store = InMemoryHouseholdStore()
        var household = try Household.open(in: store, clock: .testing)
        let house = household.categories[0]
        try household.addBill(.cityPower(in: household))

        let home = try household.renameCategory(house.id, to: " Home ")

        #expect(home.id == house.id)
        #expect(home.position == house.position)
        #expect(household.categories.map(\.name) == ["Home", "Education", "Credit Cards"])
        #expect(household.billsList.groups[0].category.name == "Home")
        #expect(household.billsList.groups[0].bills.map(\.name) == ["City Power"])
        #expect(try household.openBillingMonth(.september).groups.map(\.category.name) == ["Home"])
        #expect(try Household.open(in: store, clock: .testing).categories == household.categories)
    }

    @Test("a Category can be renamed to its own name in another case")
    func aCategoryIsRenamedInAnotherCase() throws {
        var household = try Household.open(in: InMemoryHouseholdStore(), clock: .testing)

        try household.renameCategory(household.categories[0].id, to: "HOUSE")

        #expect(household.categories.map(\.name) == ["HOUSE", "Education", "Credit Cards"])
    }

    @Test("a rename to no name, or to the name of another Category, is refused and the name is kept")
    func aRenameThatBreaksARuleIsRefused() throws {
        var household = try Household.open(in: InMemoryHouseholdStore(), clock: .testing)
        let house = household.categories[0]

        let noName = #expect(throws: CategoryRefusal.self) { try household.renameCategory(house.id, to: " ") }
        let taken = #expect(throws: CategoryRefusal.self) { try household.renameCategory(house.id, to: "education") }

        #expect(noName?.localizedDescription == "Enter a name")
        #expect(taken?.localizedDescription == "There is already a Category named Education")
        #expect(household.categories.map(\.name) == ["House", "Education", "Credit Cards"])
    }

    @Test("Credit Cards cannot be renamed, since its name is what makes its Bills credit cards")
    func creditCardsCannotBeRenamed() throws {
        var household = try Household.open(in: InMemoryHouseholdStore(), clock: .testing)
        let creditCards = household.categories[2]

        let refusal = #expect(throws: CategoryRefusal.self) { try household.renameCategory(creditCards.id, to: "Cards") }

        #expect(refusal?.localizedDescription == "Credit Cards cannot be renamed; its name is what makes its Bills credit cards")
        #expect(household.categories[2].name == "Credit Cards")
        #expect(try household.renameCategory(creditCards.id, to: "Credit Cards") == creditCards)
    }

    @Test("a Category renamed to Credit Cards, once there is none, makes its Bills credit cards")
    func aCategoryRenamedToCreditCardsHoldsCreditCards() throws {
        var household = try Household.open(in: InMemoryHouseholdStore(), clock: .testing)
        try household.deleteCategory(household.categories[2].id)
        try household.addBill(.cityPower(in: household))

        try household.renameCategory(household.categories[0].id, to: "Credit Cards")

        let board = try household.openBillingMonth(.september)
        #expect(board.takesPaidAmount(try #require(board.dues.first)))
    }

    @Test("Credit Cards is the Credit Cards Category whatever the case of its name", arguments: ["credit cards", "CREDIT CARDS"])
    func creditCardsWhateverTheCase(name: String) throws {
        var household = try Household.open(in: InMemoryHouseholdStore(), clock: .testing)
        try household.deleteCategory(household.categories[2].id)
        let cards = try household.addCategory(named: name)
        try household.addBill(NewBill(
            name: "Visa", categoryID: cards.id, dueDay: 25, dueMonth: .sameMonth, defaultAmount: nil
        ))

        let board = try household.openBillingMonth(.september)
        #expect(board.takesPaidAmount(try #require(board.dues.first)))
        #expect(try household.renameCategory(cards.id, to: "Credit Cards").name == "Credit Cards")
    }

    @Test("renaming a Category that no longer exists is refused")
    func renamingAnUnknownCategoryIsRefused() throws {
        var household = try Household.open(in: InMemoryHouseholdStore(), clock: .testing)

        let refusal = #expect(throws: CategoryRefusal.self) { try household.renameCategory(UUID(), to: "Home") }

        #expect(refusal == .noSuchCategory)
    }

    @Test("an empty Category is deleted, and stays deleted when the Household is opened again")
    func anEmptyCategoryIsDeleted() throws {
        let store = InMemoryHouseholdStore()
        var household = try Household.open(in: store, clock: .testing)

        try household.deleteCategory(household.categories[1].id)

        #expect(household.categories.map(\.name) == ["House", "Credit Cards"])
        #expect(household.billsList.groups.map(\.category.name) == ["House", "Credit Cards"])
        #expect(try Household.open(in: store, clock: .testing).categories.map(\.name) == ["House", "Credit Cards"])
    }

    @Test("a Category that still holds Bills, Retired ones too, is not deleted, with a readable reason")
    func aCategoryHoldingBillsIsNotDeleted() throws {
        var household = try Household.open(in: InMemoryHouseholdStore(), clock: .testing)
        let house = household.categories[0]
        try household.addBill(.cityPower(in: household))
        let water = try household.addBill(.water(in: household))
        try household.retireBill(water.id)

        let refusal = #expect(throws: CategoryRefusal.self) { try household.deleteCategory(house.id) }

        #expect(refusal?.localizedDescription == "House still holds 2 Bills; move them to another Category first")
        #expect(household.categories.map(\.name) == ["House", "Education", "Credit Cards"])
    }

    @Test("a Category holding one Bill says so in the singular")
    func aCategoryHoldingOneBillIsNotDeleted() throws {
        var household = try Household.open(in: InMemoryHouseholdStore(), clock: .testing)
        try household.addBill(.cityPower(in: household))

        let refusal = #expect(throws: CategoryRefusal.self) { try household.deleteCategory(household.categories[0].id) }

        #expect(refusal?.localizedDescription == "House still holds 1 Bill; move it to another Category first")
    }

    @Test("a Category whose Bills have moved away is not deleted while Dues of past months are still in it")
    func aCategoryHoldingDuesIsNotDeleted() throws {
        var household = try Household.open(in: InMemoryHouseholdStore(), clock: .testing)
        let house = household.categories[0]
        let cityPower = try household.addBill(.cityPower(in: household))
        try household.openBillingMonth(.august)
        var details = NewBill(cityPower)
        details.categoryID = household.categories[1].id
        try household.editBill(cityPower.id, to: details)

        let refusal = #expect(throws: CategoryRefusal.self) { try household.deleteCategory(house.id) }

        #expect(refusal?.localizedDescription == "House still holds Dues of past Billing Months, so it is kept")
        #expect(try household.openBillingMonth(.august).groups.map(\.category.name) == ["House"])
    }

    @Test("reordered Categories set the order of the Bills list and the Billing Month, and keep it when opened again")
    func categoriesAreReordered() throws {
        let store = InMemoryHouseholdStore()
        var household = try Household.open(in: store, clock: .testing)
        let (house, education, creditCards) = (household.categories[0], household.categories[1], household.categories[2])
        try household.addBill(.cityPower(in: household))
        try household.addBill(.riversideSchool(in: household))
        try household.addBill(.visa(in: household))

        try household.reorderCategories([creditCards.id, house.id, education.id])

        let order = ["Credit Cards", "House", "Education"]
        #expect(household.categories.map(\.name) == order)
        #expect(household.billsList.groups.map(\.category.name) == order)
        #expect(try household.openBillingMonth(.september).groups.map(\.category.name) == order)
        #expect(try household.openBillingMonth(.september).dues.map(\.name) == ["Visa", "City Power", "Riverside School"])
        #expect(try Household.open(in: store, clock: .testing).categories.map(\.name) == order)
    }

    @Test("a Category created after a reorder goes last")
    func aCategoryCreatedAfterAReorderGoesLast() throws {
        var household = try Household.open(in: InMemoryHouseholdStore(), clock: .testing)
        try household.reorderCategories(household.categories.reversed().map(\.id))

        try household.addCategory(named: "Utilities")

        #expect(household.categories.map(\.name) == ["Credit Cards", "Education", "House", "Utilities"])
    }

    @Test("an order that leaves out a Category, or names one that does not exist, is refused and the order is kept")
    func anOrderThatIsNotTheCategoriesIsRefused() throws {
        var household = try Household.open(in: InMemoryHouseholdStore(), clock: .testing)
        let ids = household.categories.map(\.id)

        let leftOut = #expect(throws: CategoryRefusal.self) { try household.reorderCategories([ids[1], ids[0]]) }
        let unknown = #expect(throws: CategoryRefusal.self) {
            try household.reorderCategories([ids[1], ids[0], UUID()])
        }
        let twice = #expect(throws: CategoryRefusal.self) {
            try household.reorderCategories([ids[1], ids[0], ids[0]])
        }

        #expect(leftOut?.localizedDescription == "The Categories changed meanwhile; try again")
        #expect(unknown == .categoriesChanged)
        #expect(twice == .categoriesChanged)
        #expect(household.categories.map(\.name) == ["House", "Education", "Credit Cards"])
    }
}
