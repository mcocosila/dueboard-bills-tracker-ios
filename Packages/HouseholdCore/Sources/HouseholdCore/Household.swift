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
        guard let categoryID = new.categoryID, records.categories.contains(where: { $0.id == categoryID }) else {
            throw BillRefusal.noCategory
        }
        guard DueDay.days.contains(new.dueDay) else { throw BillRefusal.dueDayOutOfRange }
        let bill = Bill(
            id: UUID(), name: name, categoryID: categoryID,
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

    /// The Billing Month's board, opening the month first if it has never been
    /// opened: a Due for each Recurring Bill. A month already open is shown as it is,
    /// and a month is not opened while there is no Recurring Bill, so the Bills a new
    /// Household adds on its first day still get their Dues in the current month.
    /// Any past month can be opened, and the month after the current one; no later.
    public mutating func openBillingMonth(_ month: BillingMonth) throws -> MonthBoard {
        guard (1...12).contains(month.month), month >= .earliest else { throw BillingMonthRefusal.notACalendarMonth }
        guard month <= latestOpenableMonth else { throw BillingMonthRefusal.tooFarAhead }
        let recurring = records.bills.filter(\.isRecurring)
        if !records.billingMonths.contains(month), !recurring.isEmpty {
            let now = clock.now
            let dues = recurring.map { Due(generatedFrom: $0, in: month, at: now) }
            try store.open(month, with: dues)
            records.billingMonths.insert(month)
            records.dues.append(contentsOf: dues)
        }
        return MonthBoard(
            month: month, dues: records.dues.filter { $0.billingMonth == month }, categories: categories,
            latestOpenable: latestOpenableMonth
        )
    }

    /// Enters or changes the Amount of a Due that is not Paid, or clears it with nil,
    /// leaving the Bill's Default Amount alone. An Amount of zero leaves nothing to pay,
    /// so it also marks the Due Paid by `member`.
    @discardableResult
    public mutating func enterAmount(_ amount: Decimal?, on dueID: Due.ID, by member: String) throws -> Due {
        let now = clock.now
        return try changeDue(dueID) { due in
            guard due.paid == nil else { throw DueRefusal.paidNotEditable }
            guard (amount ?? 0) >= 0 else { throw DueRefusal.negativeAmount }
            due.amount = amount
            if amount == 0 {
                due.paid = Due.Paid(at: now, by: member)
            }
        }
    }

    /// Marks a Due Paid by `member`, now. A Due already Paid keeps who marked it and when.
    @discardableResult
    public mutating func markPaid(_ dueID: Due.ID, by member: String) throws -> Due {
        let now = clock.now
        return try changeDue(dueID) { due in
            if due.paid == nil {
                due.paid = Due.Paid(at: now, by: member)
            }
        }
    }

    /// Edit: undoes Paid, so the Due is owed again and its Amount can be changed.
    @discardableResult
    public mutating func undoPaid(_ dueID: Due.ID) throws -> Due {
        try changeDue(dueID) { due in due.paid = nil }
    }

    /// Applies `change` to the Due and keeps the result, or keeps nothing when
    /// `change` throws.
    private mutating func changeDue(_ dueID: Due.ID, _ change: (inout Due) throws -> Void) throws -> Due {
        guard let index = records.dues.firstIndex(where: { $0.id == dueID }) else { throw DueRefusal.noSuchDue }
        var due = records.dues[index]
        try change(&due)
        try store.update(due)
        records.dues[index] = due
        return due
    }

    /// The Billing Month that "now" falls in, in the clock's time zone.
    public var currentBillingMonth: BillingMonth {
        let parts = clock.calendar.dateComponents([.year, .month], from: clock.now)
        return BillingMonth(year: parts.year!, month: parts.month!)
    }

    /// The furthest month that may be opened: the one after the current month.
    private var latestOpenableMonth: BillingMonth {
        currentBillingMonth.shifted(by: 1)
    }
}
