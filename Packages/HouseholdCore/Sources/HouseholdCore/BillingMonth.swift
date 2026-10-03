/// The calendar month in which a Due must be paid (see CONTEXT.md).
public struct BillingMonth: Hashable, Sendable {
    public let year: Int
    /// 1 for January through 12 for December.
    public let month: Int

    public init(year: Int, month: Int) {
        self.year = year
        self.month = month
    }
}
