import Foundation

/// Something paid from a Billing Month, described once (see GLOSSARY.md). Editing it
/// changes only the Dues generated afterwards.
public struct Bill: Hashable, Identifiable, Sendable {
    public let id: UUID
    public internal(set) var name: String
    public internal(set) var categoryID: Category.ID
    public internal(set) var dueDay: DueDay
    public internal(set) var defaultAmount: Decimal?
    /// Recurring when true, Occasional when false.
    public internal(set) var isRecurring: Bool
    /// Card-Paid when true, Direct when false: its Dues are left out of Unpaid Remaining.
    public internal(set) var isCardPaid: Bool
    /// A Retired Bill gets no Dues, generated or added by hand, until it is reactivated.
    public internal(set) var isRetired: Bool
    /// Orders the Bills of a Category, lowest first. Each new Bill gets one past every
    /// Bill's, so it lands last in whichever Category it is given.
    public let position: Int

    public init(
        id: UUID, name: String, categoryID: Category.ID, dueDay: DueDay, defaultAmount: Decimal?,
        isRecurring: Bool, isCardPaid: Bool = false, isRetired: Bool = false, position: Int
    ) {
        self.id = id
        self.name = name
        self.categoryID = categoryID
        self.dueDay = dueDay
        self.defaultAmount = defaultAmount
        self.isRecurring = isRecurring
        self.isCardPaid = isCardPaid
        self.isRetired = isRetired
        self.position = position
    }

    /// Whether opening a Billing Month generates a Due for this Bill: Recurring and not Retired.
    var isGenerated: Bool { isRecurring && !isRetired }
}

/// The day number a Bill is due on, in the Billing Month itself or the month after.
public struct DueDay: Hashable, Sendable {
    /// 1 to 28, so the day exists in every month.
    public let day: Int
    public let month: DueMonth

    /// The day numbers a Due Day may be.
    public static let days = 1...28

    public init(day: Int, month: DueMonth) {
        self.day = day
        self.month = month
    }
    /// The Due Date this Due Day gives in `billingMonth`.
    func dueDate(in billingMonth: BillingMonth) -> DueDate {
        let month = self.month == .sameMonth ? billingMonth : billingMonth.shifted(by: 1)
        return DueDate(year: month.year, month: month.month, day: day)
    }
}

/// Which month a Due Day falls in, relative to the Billing Month.
public enum DueMonth: String, Sendable {
    case sameMonth
    case nextMonth
}

/// What is filled in to add or edit a Bill. Nothing is checked until it is saved.
public struct NewBill: Sendable {
    public var name: String
    public var categoryID: Category.ID?
    public var dueDay: Int
    public var dueMonth: DueMonth
    public var defaultAmount: Decimal?
    /// Recurring when true, Occasional when false.
    public var isRecurring: Bool
    /// Card-Paid when true, Direct when false.
    public var isCardPaid: Bool

    public init(
        name: String, categoryID: Category.ID?, dueDay: Int, dueMonth: DueMonth, defaultAmount: Decimal?,
        isRecurring: Bool = true, isCardPaid: Bool = false
    ) {
        self.name = name
        self.categoryID = categoryID
        self.dueDay = dueDay
        self.dueMonth = dueMonth
        self.defaultAmount = defaultAmount
        self.isRecurring = isRecurring
        self.isCardPaid = isCardPaid
    }

    /// The Bill as it is now, to be edited.
    public init(_ bill: Bill) {
        self.init(
            name: bill.name, categoryID: bill.categoryID, dueDay: bill.dueDay.day, dueMonth: bill.dueDay.month,
            defaultAmount: bill.defaultAmount, isRecurring: bill.isRecurring, isCardPaid: bill.isCardPaid
        )
    }
}
