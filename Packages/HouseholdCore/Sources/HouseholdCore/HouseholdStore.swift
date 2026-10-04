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
    /// Keeps a Billing Month that has just been opened, with the Dues it was
    /// opened with, all or nothing.
    func open(_ month: BillingMonth, with dues: [Due]) throws
    /// Keeps a Due's Amount and Paid as they now are.
    func update(_ due: Due) throws
}

/// Everything a Household is made of, as a store keeps it.
public struct HouseholdRecords: Sendable {
    public var categories: [Category]
    public var bills: [Bill]
    /// The Billing Months opened so far, each one once.
    public var billingMonths: Set<BillingMonth>
    public var dues: [Due]

    public init(categories: [Category], bills: [Bill] = [], billingMonths: Set<BillingMonth> = [], dues: [Due] = []) {
        self.categories = categories
        self.bills = bills
        self.billingMonths = billingMonths
        self.dues = dues
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

    public func open(_ month: BillingMonth, with dues: [Due]) throws {
        household?.billingMonths.insert(month)
        household?.dues.append(contentsOf: dues)
    }

    public func update(_ due: Due) throws {
        guard let index = household?.dues.firstIndex(where: { $0.id == due.id }) else { return }
        household?.dues[index] = due
    }
}
