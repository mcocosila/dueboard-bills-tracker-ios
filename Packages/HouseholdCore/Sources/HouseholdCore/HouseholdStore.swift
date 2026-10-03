/// Where a Household is kept between launches. The app keeps it in Core Data;
/// tests keep it in memory. A store only keeps and returns what it is given:
/// every rule stays in `Household`.
public protocol HouseholdStore: AnyObject {
    /// The Household this store keeps, or nil when none has been started yet.
    func load() throws -> HouseholdRecords?
    /// Keeps a Household that has just been started.
    func start(_ household: HouseholdRecords) throws
    /// Keeps a Bill that has just been added.
    func insert(_ bill: Bill) throws
}

/// Everything a Household is made of, as a store keeps it.
public struct HouseholdRecords: Sendable {
    public var categories: [Category]
    public var bills: [Bill]

    public init(categories: [Category], bills: [Bill] = []) {
        self.categories = categories
        self.bills = bills
    }
}

/// A store that forgets everything when it goes away. For tests and previews.
public final class InMemoryHouseholdStore: HouseholdStore {
    private var household: HouseholdRecords?

    public init() {}

    public func load() throws -> HouseholdRecords? {
        household
    }

    public func start(_ household: HouseholdRecords) throws {
        self.household = household
    }

    public func insert(_ bill: Bill) throws {
        household?.bills.append(bill)
    }
}
