import Foundation

/// One Bill in one Billing Month (see CONTEXT.md). Generated from the Bill and
/// then independent of it: the name, Category, order and Card-Paid are the Bill's as
/// they were when the Due was generated.
public struct Due: Hashable, Identifiable, Sendable {
    public let id: UUID
    public let billID: Bill.ID
    public let billingMonth: BillingMonth
    public let name: String
    public let categoryID: Category.ID
    /// The Bill's position when the Due was generated; breaks ties between Dues with the same Due Date.
    public let position: Int
    public let dueDate: DueDate
    /// A Card-Paid Due is left out of Unpaid Remaining.
    public let isCardPaid: Bool
    /// Nil until entered, unless pre-filled from the Bill's Default Amount.
    public internal(set) var amount: Decimal?
    /// When and by whom the Due was marked Paid, or nil while it is not Paid.
    public internal(set) var paid: Paid?

    public init(
        id: UUID, billID: Bill.ID, billingMonth: BillingMonth, name: String, categoryID: Category.ID, position: Int,
        dueDate: DueDate, isCardPaid: Bool, amount: Decimal?, paid: Paid?
    ) {
        self.id = id
        self.billID = billID
        self.billingMonth = billingMonth
        self.name = name
        self.categoryID = categoryID
        self.position = position
        self.dueDate = dueDate
        self.isCardPaid = isCardPaid
        self.amount = amount
        self.paid = paid
    }

    /// A new Due for `bill` in `month`, its Due Date computed from the Due Day and its
    /// Amount pre-filled from the Default Amount. A Default Amount of zero leaves nothing
    /// to pay, so the Due is Paid from birth, at `now` and by nobody.
    init(generatedFrom bill: Bill, in month: BillingMonth, at now: Date) {
        self.init(
            id: UUID(), billID: bill.id, billingMonth: month, name: bill.name, categoryID: bill.categoryID,
            position: bill.position, dueDate: bill.dueDay.dueDate(in: month), isCardPaid: bill.isCardPaid,
            amount: bill.defaultAmount, paid: nil
        )
        if bill.defaultAmount == 0 {
            markPaid(at: now, by: nil)
        }
    }

    /// Marks the Due Paid, unless it already is: a Paid Due keeps who marked it, when and
    /// its Paid Amount. `paidAmount`, handed only for a credit card Due, is kept only when it
    /// leaves an Unpaid Balance: more than zero and less than an Amount the Due has. Anything
    /// else is a full payment.
    mutating func markPaid(at now: Date, by member: String?, paying paidAmount: Decimal? = nil) {
        guard paid == nil else { return }
        let leavesUnpaidBalance = paidAmount.map { $0 > 0 && $0 < (amount ?? 0) } == true
        paid = Paid(at: now, by: member, paidAmount: leavesUnpaidBalance ? paidAmount : nil)
    }

    /// Whether this is a credit card Due, one in the Credit Cards Category, among the
    /// Household's `categories`.
    func isCreditCard(among categories: [Category]) -> Bool {
        categories.first { $0.id == categoryID }?.isCreditCards == true
    }

    /// Amount minus Paid Amount on a Paid credit card Due: what the card still holds. Zero
    /// when the Due was paid in full or is not Paid.
    public var unpaidBalance: Decimal {
        guard let paidAmount = paid?.paidAmount, let amount else { return 0 }
        return amount - paidAmount
    }

    /// When a Due was marked Paid, by whom and, on a credit card Due paid for less than its
    /// Amount, for how much (see Paid in CONTEXT.md).
    public struct Paid: Hashable, Sendable {
        public let at: Date
        /// The name of whoever marked it Paid, or nil when it was Paid from birth.
        public let by: String?
        /// What was paid on a credit card Due paid for less than its Amount, or nil when its
        /// whole Amount was paid.
        public let paidAmount: Decimal?

        public init(at: Date, by: String?, paidAmount: Decimal?) {
            self.at = at
            self.by = by
            self.paidAmount = paidAmount
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
