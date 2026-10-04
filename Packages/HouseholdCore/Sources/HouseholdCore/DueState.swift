import Foundation

/// What a Due's row says at a glance: Paid, Due Soon or Overdue (see CONTEXT.md).
/// Derived from the Due and today, never stored. A Due that is not Paid and due more
/// than 7 days ahead has none.
public enum DueState: Hashable, Sendable {
    case paid
    case dueSoon
    case overdue

    /// How many days ahead of today a Due Date still counts as Due Soon.
    static let dueSoonDays = 7
}

extension Due {
    /// The Due's state on `today`, or nil when nothing needs saying. `soonest` is the last
    /// day that counts as Due Soon.
    func state(on today: DueDate, dueSoonThrough soonest: DueDate) -> DueState? {
        if paid != nil { return .paid }
        if dueDate < today { return .overdue }
        if dueDate <= soonest { return .dueSoon }
        return nil
    }
}

extension DueDate {
    /// The calendar date `date` falls on in `calendar`'s time zone.
    init(of date: Date, in calendar: Calendar) {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(year: parts.year!, month: parts.month!, day: parts.day!)
    }
}
