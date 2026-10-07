import HouseholdCore
import Observation
import UserNotifications

/// The notification adapter: makes the phone's pending notifications match the household
/// core's reminder plan, adding what is missing and removing what is no longer planned, clears
/// the notifications already shown for Dues no longer reminded, and hands on the Billing Month
/// of a notification that is tapped. It holds no rules: which
/// Reminders exist, when and with what text is the core's answer.
@MainActor @Observable
final class ReminderNotifications: NSObject {
    /// The Billing Month of the notification last tapped, until the Month board has shown it.
    var monthToOpen: BillingMonth?

    @ObservationIgnored private let center = UNUserNotificationCenter.current()
    /// The last change of the pending notifications, so each starts once the one before it
    /// has finished and never works from a list of pending ones about to change.
    @ObservationIgnored private var lastMatch: Task<Void, Never>?

    /// Set up as the app starts, so a tap that launched the app is not missed.
    override init() {
        super.init()
        center.delegate = self
    }

    /// Whether the phone has not been asked yet to allow notifications.
    func permissionNotAsked() async -> Bool {
        await center.notificationSettings().authorizationStatus == .notDetermined
    }

    /// Asks the phone to allow notifications, then makes the pending ones match `plan`.
    func askPermission(thenMatch plan: [Reminder], reminding remindedDues: Set<Due.ID>) {
        Task {
            _ = try? await center.requestAuthorization(options: [.alert, .sound])
            match(plan, reminding: remindedDues)
        }
    }

    /// Makes the pending notifications match `plan`, and clears those already shown for a Due
    /// not among `remindedDues`: Paid, removed or Retired since. Does nothing while
    /// notifications are declined or not allowed yet: the app works the same without them.
    func match(_ plan: [Reminder], reminding remindedDues: Set<Due.ID>) {
        let previous = lastMatch
        lastMatch = Task {
            await previous?.value
            await replacePending(with: plan, reminding: remindedDues)
        }
    }

    private func replacePending(with plan: [Reminder], reminding remindedDues: Set<Due.ID>) async {
        let status = await center.notificationSettings().authorizationStatus
        guard [.authorized, .provisional, .ephemeral].contains(status) else { return }
        let planned = Dictionary(uniqueKeysWithValues: plan.map { ($0.id, $0) })
        let pending = await center.pendingNotificationRequests()
        // A Reminder whose time or text has changed, after a change of time zone or of the
        // Due's name, is removed and added again.
        let stale = pending.filter { request in planned[request.identifier].map { !request.notifies($0) } ?? true }
        center.removePendingNotificationRequests(withIdentifiers: stale.map(\.identifier))
        let kept = Set(pending.map(\.identifier)).subtracting(stale.map(\.identifier))
        for reminder in plan where !kept.contains(reminder.id) {
            try? await center.add(UNNotificationRequest(reminder))
        }
        let shown = await center.deliveredNotifications().map(\.request)
        let done = shown.filter { request in request.dueID.map { !remindedDues.contains($0) } ?? false }
        center.removeDeliveredNotifications(withIdentifiers: done.map(\.identifier))
    }
}

// iOS calls these on the main thread and expects its completion handler called there too. The
// async forms run on a background thread and call it from there, which crashes the app as a tap
// opens it, so the completion handler forms are used, on the main actor.
extension ReminderNotifications: @preconcurrency UNUserNotificationCenterDelegate {
    /// A notification tapped opens its Due's Billing Month.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if let month = BillingMonth(response.notification.request.content.userInfo) {
            monthToOpen = month
        }
        completionHandler()
    }

    /// A Reminder that fires while the app is open shows as a banner all the same.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter, willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }
}

private extension UNNotificationRequest {
    /// The pending notification for `reminder`, firing at its time on the phone's clock.
    convenience init(_ reminder: Reminder) {
        let content = UNMutableNotificationContent()
        content.title = reminder.title
        content.body = reminder.body
        content.sound = .default
        content.userInfo = reminder.userInfo
        let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminder.fireDate)
        self.init(
            identifier: reminder.id, content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
        )
    }

    /// The Due this notification reminds of, or nil for one that does not say.
    var dueID: Due.ID? {
        (content.userInfo[dueIDKey] as? String).flatMap(UUID.init(uuidString:))
    }

    /// Whether this pending notification is the one `reminder` plans: same time and text.
    func notifies(_ reminder: Reminder) -> Bool {
        content.title == reminder.title && content.body == reminder.body
            && content.userInfo[fireDateKey] as? TimeInterval == reminder.fireDate.timeIntervalSince1970
    }
}

private extension Reminder {
    /// What the notification carries: the Billing Month to open when it is tapped, the fire
    /// time it was planned for, and its Due, to clear it once the Due is no longer reminded.
    var userInfo: [String: Any] {
        [
            yearKey: billingMonth.year, monthKey: billingMonth.month, fireDateKey: fireDate.timeIntervalSince1970,
            dueIDKey: dueID.uuidString,
        ]
    }
}

private extension BillingMonth {
    /// The Billing Month a notification carries, or nil when it carries none.
    init?(_ userInfo: [AnyHashable: Any]) {
        guard let year = userInfo[yearKey] as? Int, let month = userInfo[monthKey] as? Int else { return nil }
        self.init(year: year, month: month)
    }
}

private let yearKey = "billingMonthYear"
private let monthKey = "billingMonthMonth"
private let fireDateKey = "fireDate"
private let dueIDKey = "dueID"
