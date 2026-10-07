/// The calendar month in which a Due must be paid (see GLOSSARY.md).
public struct BillingMonth: Hashable, Comparable, Sendable {
    public let year: Int
    /// 1 for January through 12 for December.
    public let month: Int

    public init(year: Int, month: Int) {
        self.year = year
        self.month = month
    }

    /// January of year 1, the start of the calendar: nothing before it can be opened.
    public static let earliest = BillingMonth(year: 1, month: 1)

    /// The month `count` months after this one, or before it when `count` is negative.
    public func shifted(by count: Int) -> BillingMonth {
        let index = year * 12 + (month - 1) + count
        let (year, month) = index.quotientAndRemainder(dividingBy: 12)
        return month < 0 ? BillingMonth(year: year - 1, month: month + 13) : BillingMonth(year: year, month: month + 1)
    }

    public static func < (lhs: BillingMonth, rhs: BillingMonth) -> Bool {
        (lhs.year, lhs.month) < (rhs.year, rhs.month)
    }
}
