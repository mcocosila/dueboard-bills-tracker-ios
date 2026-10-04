/// A Billing Month as the Month board shows it: its Dues grouped by Category, and
/// its Unpaid Remaining.
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

    /// Every Due of the month, in board order.
    public var dues: [Due] { groups.flatMap(\.dues) }

    init(month: BillingMonth, dues: [Due], categories: [Category], latestOpenable: BillingMonth) {
        self.month = month
        previous = month > .earliest ? month.shifted(by: -1) : nil
        next = month < latestOpenable ? month.shifted(by: 1) : nil
        unpaidRemaining = UnpaidRemaining(of: dues)
        groups = categories.compactMap { category in
            let dues = dues.filter { $0.categoryID == category.id }.sorted { ($0.dueDate, $0.position) < ($1.dueDate, $1.position) }
            return dues.isEmpty ? nil : Group(category: category, dues: dues)
        }
    }
}
