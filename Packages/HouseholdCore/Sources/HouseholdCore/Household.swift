import Foundation

/// The shared set of Categories, Bills and Billing Months, and the only thing
/// the screens talk to.
public struct Household {
    private let clock: WallClock
    private let store: HouseholdStore
    private var records: HouseholdRecords

    private init(clock: WallClock, store: HouseholdStore, records: HouseholdRecords) {
        self.clock = clock
        self.store = store
        self.records = records
    }

    /// The Household kept in `store`, or a new one with the suggested Categories
    /// when the store holds none yet.
    public static func open(in store: HouseholdStore, clock: WallClock) throws -> Household {
        if let records = try store.load() {
            return Household(clock: clock, store: store, records: records)
        }
        let records = HouseholdRecords(categories: Category.suggested())
        try store.start(records)
        return Household(clock: clock, store: store, records: records)
    }

    /// The Household's Categories, in their order.
    public var categories: [Category] {
        records.categories.sorted { $0.position < $1.position }
    }

    /// Adds a Bill, Recurring, last in its Category.
    @discardableResult
    public mutating func addBill(_ new: NewBill) throws -> Bill {
        let name = new.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw BillRefusal.noName }
        guard DueDay.days.contains(new.dueDay) else { throw BillRefusal.dueDayOutOfRange }
        let bill = Bill(
            id: UUID(), name: name, categoryID: new.categoryID,
            dueDay: DueDay(day: new.dueDay, month: new.dueMonth), defaultAmount: new.defaultAmount,
            isRecurring: true, position: (records.bills.map(\.position).max() ?? 0) + 1
        )
        try store.insert(bill)
        records.bills.append(bill)
        return bill
    }

    /// The Bills grouped by Category, in Category order.
    public var billsList: BillsList {
        BillsList(groups: categories.map { category in
            BillsList.Group(
                category: category,
                bills: records.bills.filter { $0.categoryID == category.id }.sorted { $0.position < $1.position }
            )
        })
    }

    /// The Billing Month that "now" falls in, in the clock's time zone.
    public var currentBillingMonth: BillingMonth {
        let parts = clock.calendar.dateComponents([.year, .month], from: clock.now)
        return BillingMonth(year: parts.year!, month: parts.month!)
    }
}
