/// A Billing Month as the Month board shows it: its Dues grouped by Category, each
/// with its state as of the day the board was made, and its Unpaid Remaining.
public struct MonthBoard: Sendable {
    public struct Group: Identifiable, Sendable {
        public let category: Category
        /// By Due Date, the Bill order breaking a tie.
        public let dues: [Due]

        public var id: Category.ID { category.id }
    }

    public let month: BillingMonth
    /// The Categories that have Dues this month, in Category order.
    public let groups: [Group]
    /// The month before this one, or nil when this is the earliest Billing Month.
    public let previous: BillingMonth?
    /// The month after this one, or nil when it cannot be opened yet.
    public let next: BillingMonth?
    public let unpaidRemaining: UnpaidRemaining
    /// The day the board was made, in the clock's time zone.
    private let today: DueDate
    /// The last day that counts as Due Soon.
    private let dueSoonThrough: DueDate

    /// Every Due of the month, in board order.
    public var dues: [Due] { groups.flatMap(\.dues) }

    /// Paid, Due Soon or Overdue, or nil when nothing needs saying about `due`.
    public func state(of due: Due) -> DueState? {
        due.state(on: today, dueSoonThrough: dueSoonThrough)
    }

    init(
        month: BillingMonth, dues: [Due], categories: [Category], latestOpenable: BillingMonth, today: DueDate,
        dueSoonThrough: DueDate
    ) {
        self.month = month
        self.today = today
        self.dueSoonThrough = dueSoonThrough
        previous = month > .earliest ? month.shifted(by: -1) : nil
        next = month < latestOpenable ? month.shifted(by: 1) : nil
        unpaidRemaining = UnpaidRemaining(of: dues)
        groups = categories.compactMap { category in
            let dues = dues.filter { $0.categoryID == category.id }.sorted { ($0.dueDate, $0.position) < ($1.dueDate, $1.position) }
            return dues.isEmpty ? nil : Group(category: category, dues: dues)
        }
    }
}
