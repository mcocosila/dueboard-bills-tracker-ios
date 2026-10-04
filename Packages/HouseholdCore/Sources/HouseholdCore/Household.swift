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

    /// Adds a Bill, Recurring unless it is filled in as Occasional, last in its Category.
    @discardableResult
    public mutating func addBill(_ new: NewBill) throws -> Bill {
        let details = try checked(new)
        let bill = Bill(
            id: UUID(), name: details.name, categoryID: details.categoryID, dueDay: details.dueDay,
            defaultAmount: new.defaultAmount, isRecurring: new.isRecurring, isCardPaid: new.isCardPaid,
            position: (records.bills.map(\.position).max() ?? 0) + 1
        )
        try store.insert(bill)
        records.bills.append(bill)
        return bill
    }

    /// Changes a Bill's details, and whether it is Recurring or Occasional. Only the Dues
    /// generated afterwards follow: the Dues it already has, and the months already
    /// opened, are left as they are.
    @discardableResult
    public mutating func editBill(_ billID: Bill.ID, to details: NewBill) throws -> Bill {
        // An unknown Bill is refused before what is filled in is checked.
        guard records.bills.contains(where: { $0.id == billID }) else { throw BillRefusal.noSuchBill }
        let checked = try checked(details)
        return try changeBill(billID) { bill in
            bill.name = checked.name
            bill.categoryID = checked.categoryID
            bill.dueDay = checked.dueDay
            bill.defaultAmount = details.defaultAmount
            bill.isRecurring = details.isRecurring
            bill.isCardPaid = details.isCardPaid
        }
    }

    /// Retires a Bill: it gets no Dues in months opened afterwards and cannot be added by
    /// hand, while the Dues it already has remain.
    @discardableResult
    public mutating func retireBill(_ billID: Bill.ID) throws -> Bill {
        try changeBill(billID) { bill in bill.isRetired = true }
    }

    /// Reactivates a Retired Bill, so months opened afterwards get its Dues again.
    @discardableResult
    public mutating func reactivateBill(_ billID: Bill.ID) throws -> Bill {
        try changeBill(billID) { bill in bill.isRetired = false }
    }

    /// The name, Category and Due Day filled in, once each is checked against the rules.
    private func checked(_ new: NewBill) throws -> (name: String, categoryID: Category.ID, dueDay: DueDay) {
        let name = new.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw BillRefusal.noName }
        guard let categoryID = new.categoryID, records.categories.contains(where: { $0.id == categoryID }) else {
            throw BillRefusal.noCategory
        }
        guard DueDay.days.contains(new.dueDay) else { throw BillRefusal.dueDayOutOfRange }
        return (name, categoryID, DueDay(day: new.dueDay, month: new.dueMonth))
    }

    /// Applies `change` to the Bill and keeps the result, or keeps nothing when
    /// `change` throws.
    private mutating func changeBill(_ billID: Bill.ID, _ change: (inout Bill) throws -> Void) throws -> Bill {
        guard let index = records.bills.firstIndex(where: { $0.id == billID }) else { throw BillRefusal.noSuchBill }
        var bill = records.bills[index]
        try change(&bill)
        try store.update(bill)
        records.bills[index] = bill
        return bill
    }

    /// The Bills grouped by Category, in Category order, and the Retired Bills apart.
    public var billsList: BillsList {
        BillsList(bills: records.bills, categories: categories)
    }

    /// The Billing Month's board, opening the month first if it has never been
    /// opened: a Due for each Recurring Bill not Retired. A month already open is shown
    /// as it is, and a month is not opened while no Bill would get a Due in it, so the
    /// Bills a new Household adds on its first day still get their Dues in the current
    /// month. Any past month can be opened, and the month after the current one; no later.
    public mutating func openBillingMonth(_ month: BillingMonth) throws -> MonthBoard {
        try checkOpenable(month)
        if !records.billingMonths.contains(month), records.bills.contains(where: \.isGenerated) {
            try openMonth(month)
        }
        return MonthBoard(
            month: month, dues: records.dues.filter { $0.billingMonth == month }, bills: records.bills,
            categories: categories, latestOpenable: latestOpenableMonth,
            today: DueDate(of: clock.now, in: clock.calendar), dueSoonThrough: dueSoonThrough
        )
    }

    /// Adds a Bill to a Billing Month by hand, generating its Due as opening the month
    /// would. A month never opened is opened with it. A Bill already in the month is not
    /// added again: its Due is handed back as it is.
    @discardableResult
    public mutating func addDue(of billID: Bill.ID, to month: BillingMonth) throws -> Due {
        try checkOpenable(month)
        guard let bill = records.bills.first(where: { $0.id == billID }) else { throw BillRefusal.noSuchBill }
        guard !bill.isRetired else { throw BillRefusal.retired }
        if let due = records.dues.first(where: { $0.billID == billID && $0.billingMonth == month }) {
            return due
        }
        guard records.billingMonths.contains(month) else {
            return try openMonth(month, adding: bill).first { $0.billID == billID }!
        }
        let due = Due(generatedFrom: bill, in: month, at: clock.now)
        try store.insert(due)
        records.dues.append(due)
        return due
    }

    /// Removes a Due that is not Paid from its Billing Month, deleting it. Adding its Bill
    /// again generates a fresh Due.
    public mutating func removeDue(_ dueID: Due.ID) throws {
        guard let index = records.dues.firstIndex(where: { $0.id == dueID }) else { throw DueRefusal.noSuchDue }
        guard records.dues[index].paid == nil else { throw DueRefusal.paidNotRemovable }
        try store.delete(dueID)
        records.dues.remove(at: index)
    }

    /// Refuses a month that is not a Billing Month, or is too far ahead to open yet.
    private func checkOpenable(_ month: BillingMonth) throws {
        guard (1...12).contains(month.month), month >= .earliest else { throw BillingMonthRefusal.notACalendarMonth }
        guard month <= latestOpenableMonth else { throw BillingMonthRefusal.tooFarAhead }
    }

    /// Opens a month never opened, with a Due for each Recurring Bill not Retired and
    /// one for `added` when it is not among them.
    @discardableResult
    private mutating func openMonth(_ month: BillingMonth, adding added: Bill? = nil) throws -> [Due] {
        let now = clock.now
        var bills = records.bills.filter(\.isGenerated)
        if let added, !bills.contains(where: { $0.id == added.id }) {
            bills.append(added)
        }
        let dues = bills.map { Due(generatedFrom: $0, in: month, at: now) }
        try store.open(month, with: dues)
        records.billingMonths.insert(month)
        records.dues.append(contentsOf: dues)
        return dues
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
                due.markPaid(at: now, by: member)
            }
        }
    }

    /// Marks a Due Paid by `member`, now. On a credit card Due, `paidAmount` is what was paid
    /// when it is less than the Amount, leaving the rest as Unpaid Balance; nil means the whole
    /// Amount, and other Dues are always paid in full. A Due already Paid keeps who marked it,
    /// when and its Paid Amount: only Edit and marking Paid again change them.
    @discardableResult
    public mutating func markPaid(_ dueID: Due.ID, paying paidAmount: Decimal? = nil, by member: String) throws -> Due {
        let now = clock.now
        let categories = records.categories
        return try changeDue(dueID) { due in
            guard (paidAmount ?? 0) >= 0 else { throw DueRefusal.negativePaidAmount }
            due.markPaid(at: now, by: member, paying: due.isCreditCard(among: categories) ? paidAmount : nil)
        }
    }

    /// Edit: undoes Paid, taking its Paid Amount with it, so the Due is owed again and its
    /// Amount can be changed.
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
        let today = DueDate(of: clock.now, in: clock.calendar)
        return BillingMonth(year: today.year, month: today.month)
    }

    /// The last day that counts as Due Soon: 7 days after today, in the clock's time zone.
    private var dueSoonThrough: DueDate {
        let calendar = clock.calendar
        return DueDate(of: calendar.date(byAdding: .day, value: DueState.dueSoonDays, to: clock.now)!, in: calendar)
    }

    /// The furthest month that may be opened: the one after the current month.
    private var latestOpenableMonth: BillingMonth {
        currentBillingMonth.shifted(by: 1)
    }
}
