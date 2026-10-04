import Foundation

/// One Bill in one Billing Month (see CONTEXT.md). Generated from the Bill and
/// then independent of it: the name, Category and order are the Bill's as they
/// were when the Due was generated.
public struct Due: Hashable, Identifiable, Sendable {
    public let id: UUID
    public let billID: Bill.ID
    public let billingMonth: BillingMonth
    public let name: String
    public let categoryID: Category.ID
    /// The Bill's position when the Due was generated; breaks ties between Dues with the same Due Date.
    public let position: Int
    public let dueDate: DueDate
    /// Nil until entered, unless pre-filled from the Bill's Default Amount.
    public internal(set) var amount: Decimal?
    /// When and by whom the Due was marked Paid, or nil while it is not Paid.
    public internal(set) var paid: Paid?

    public init(
        id: UUID, billID: Bill.ID, billingMonth: BillingMonth, name: String, categoryID: Category.ID, position: Int,
        dueDate: DueDate, amount: Decimal?, paid: Paid?
    ) {
        self.id = id
        self.billID = billID
        self.billingMonth = billingMonth
        self.name = name
        self.categoryID = categoryID
        self.position = position
        self.dueDate = dueDate
        self.amount = amount
        self.paid = paid
    }

    /// A new Due for `bill` in `month`, its Due Date computed from the Due Day and its
    /// Amount pre-filled from the Default Amount. A Default Amount of zero leaves nothing
    /// to pay, so the Due is Paid from birth, at `now` and by nobody.
    init(generatedFrom bill: Bill, in month: BillingMonth, at now: Date) {
        self.init(
            id: UUID(), billID: bill.id, billingMonth: month, name: bill.name, categoryID: bill.categoryID,
            position: bill.position, dueDate: bill.dueDay.dueDate(in: month), amount: bill.defaultAmount,
            paid: nil
        )
        if bill.defaultAmount == 0 {
            markPaid(at: now, by: nil)
        }
    }

    /// Marks the Due Paid, unless it already is: a Paid Due keeps who marked it and when.
    mutating func markPaid(at now: Date, by member: String?) {
        if paid == nil {
            paid = Paid(at: now, by: member)
        }
    }

    /// When a Due was marked Paid and by whom (see Paid in CONTEXT.md).
    public struct Paid: Hashable, Sendable {
        public let at: Date
        /// The name of whoever marked it Paid, or nil when it was Paid from birth.
        public let by: String?

        public init(at: Date, by: String?) {
            self.at = at
            self.by = by
        }
    }
}

/// The calendar date a Due must be paid by (see CONTEXT.md). A day on the
/// calendar, not a moment in time, so it is the same date in every time zone.
public struct DueDate: Hashable, Comparable, Sendable {
    public let year: Int
    /// 1 for January through 12 for December.
    public let month: Int
    public let day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    public static func < (lhs: DueDate, rhs: DueDate) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }
}
