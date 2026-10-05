import Foundation

/// A notification planned from a Due's state (see CONTEXT.md). The core only plans
/// Reminders; the app's notification adapter makes the phone's pending notifications
/// match the plan.
public struct Reminder: Hashable, Identifiable, Sendable {
    /// Which of a Due's three Reminders this is.
    public enum Kind: String, Hashable, Sendable {
        /// On the day the Due becomes Due Soon, 7 days before its Due Date.
        case dueSoon
        /// On its Due Date.
        case dueDate
        /// On the day after its Due Date, when it is Overdue.
        case overdue

        /// How many days after the Due Date the Reminder fires, before it when negative.
        var daysAfterDueDate: Int {
            switch self {
            case .dueSoon: -DueState.dueSoonDays
            case .dueDate: 0
            case .overdue: 1
            }
        }

        /// Why the Reminder is sent.
        var body: String {
            switch self {
            case .dueSoon: "Due Soon: due in \(DueState.dueSoonDays) days."
            case .dueDate: "Due today."
            case .overdue: "Overdue: it was due yesterday."
            }
        }
    }

    /// The same for a Due and kind every time the plan is made, so the adapter can tell
    /// what is already pending.
    public let id: String
    public let dueID: Due.ID
    /// The Billing Month the Due belongs to, which tapping the notification opens.
    public let billingMonth: BillingMonth
    public let kind: Kind
    /// 9:00 on the Reminder's day, in the clock's time zone.
    public let fireDate: Date
    /// The Due's name.
    public let title: String
    /// Why the Reminder is sent.
    public let body: String

    /// The most Reminders planned at once, the earliest first: iOS keeps no more than
    /// 64 pending notifications for an app.
    public static let limit = 64

    /// The hour of the day every Reminder fires at.
    static let hour = 9

    init(of due: Due, kind: Kind, firingAt fireDate: Date) {
        id = "\(due.id.uuidString).\(kind.rawValue)"
        dueID = due.id
        billingMonth = due.billingMonth
        self.kind = kind
        self.fireDate = fireDate
        title = due.name
        body = kind.body
    }

    /// The Reminders that should be pending at `now`: three for every Due that is not Paid
    /// and whose Bill is not Retired, less those whose time has passed, the earliest
    /// `limit` of them in fire time order.
    static func plan(for dues: [Due], bills: [Bill], at now: Date, in calendar: Calendar) -> [Reminder] {
        let retired = Set(bills.filter(\.isRetired).map(\.id))
        let reminders = dues.filter { $0.paid == nil && !retired.contains($0.billID) }.flatMap { due in
            [Kind.dueSoon, .dueDate, .overdue].compactMap { kind -> Reminder? in
                let fireDate = due.dueDate.at(hour: hour, shiftedBy: kind.daysAfterDueDate, in: calendar)
                return fireDate > now ? Reminder(of: due, kind: kind, firingAt: fireDate) : nil
            }
        }
        return reminders
            .sorted { ($0.fireDate, $0.billingMonth, $0.title, $0.id) < ($1.fireDate, $1.billingMonth, $1.title, $1.id) }
            .prefix(limit)
            .map(\.self)
    }
}

extension DueDate {
    /// `hour`:00 on the day `days` after this one, before it when negative, in `calendar`'s
    /// time zone.
    func at(hour: Int, shiftedBy days: Int, in calendar: Calendar) -> Date {
        let day = calendar.date(from: DateComponents(year: year, month: month, day: day + days))!
        return calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day)!
    }
}
