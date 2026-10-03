import Foundation

/// Something paid from a Billing Month, described once (see CONTEXT.md).
public struct Bill: Hashable, Identifiable, Sendable {
    public let id: UUID
    public let name: String
    public let categoryID: Category.ID
    public let dueDay: DueDay
    public let defaultAmount: Decimal?
    /// Recurring when true, Occasional when false.
    public let isRecurring: Bool
    /// Orders the Bills of a Category, lowest first. Each new Bill gets one past every
    /// Bill's, so it lands last in whichever Category it is given.
    public let position: Int

    public init(
        id: UUID, name: String, categoryID: Category.ID, dueDay: DueDay, defaultAmount: Decimal?,
        isRecurring: Bool, position: Int
    ) {
        self.id = id
        self.name = name
        self.categoryID = categoryID
        self.dueDay = dueDay
        self.defaultAmount = defaultAmount
        self.isRecurring = isRecurring
        self.position = position
    }
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
}

/// Which month a Due Day falls in, relative to the Billing Month.
public enum DueMonth: String, Sendable {
    case sameMonth
    case nextMonth
}

/// What is filled in to add a Bill. Nothing is checked until it is added.
public struct NewBill: Sendable {
    public var name: String
    public var categoryID: Category.ID?
    public var dueDay: Int
    public var dueMonth: DueMonth
    public var defaultAmount: Decimal?

    public init(name: String, categoryID: Category.ID?, dueDay: Int, dueMonth: DueMonth, defaultAmount: Decimal?) {
        self.name = name
        self.categoryID = categoryID
        self.dueDay = dueDay
        self.dueMonth = dueMonth
        self.defaultAmount = defaultAmount
    }
}
