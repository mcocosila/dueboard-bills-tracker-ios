import HouseholdCore
import SwiftUI

/// The app's tabs: the Billing Month and the Bills, each with a line along the bottom while
/// the phone is signed out of iCloud. Keeps the phone's pending notifications matching the
/// reminder plan after launch, after every change, including one synced from another device,
/// and on coming back to the app, asking for permission, with the reason, the first time there
/// is a Reminder to send.
struct RootView: View {
    @Binding var household: Household
    @Bindable var reminders: ReminderNotifications
    @Environment(\.scenePhase) private var scenePhase
    @Environment(ICloudAccount.self) private var iCloud
    @State private var tab = RootTab.month
    @State private var askingForPermission = false

    var body: some View {
        TabView(selection: $tab) {
            Tab("Month", systemImage: "calendar", value: .month) {
                MonthView(household: $household, monthToOpen: $reminders.monthToOpen)
                    .iCloudNotice(iCloud)
            }
            Tab("Bills", systemImage: "list.bullet", value: .bills) {
                BillsView(household: $household)
                    .iCloudNotice(iCloud)
            }
        }
        .task { await matchReminders() }
        .onChange(of: household.reminderPlan) { Task { await matchReminders() } }
        // A Due Paid after its last Reminder leaves the plan as it was, but its notification
        // still has to be cleared.
        .onChange(of: household.remindedDues) { Task { await matchReminders() } }
        // Reminders whose time has passed drop out of the plan as the days go by.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await matchReminders() }
                iCloud.check()
            }
        }
        .onChange(of: reminders.monthToOpen) { _, month in
            if month != nil { tab = .month }
        }
        .alert("Reminders", isPresented: $askingForPermission) {
            Button("Continue") { reminders.askPermission(thenMatch: household.reminderPlan, reminding: household.remindedDues) }
        } message: {
            Text("Dueboard reminds you at \(reminderTime) when a Due becomes Due Soon, on its Due Date and the day after, until it is Paid.")
        }
    }

    /// Makes the pending notifications match the plan, and asks for permission when there is
    /// a Reminder to send and the phone has not been asked yet. The plan is handed on before
    /// anything is awaited, so a later change never overtakes it.
    private func matchReminders() async {
        let plan = household.reminderPlan
        reminders.match(plan, reminding: household.remindedDues)
        if !plan.isEmpty, await reminders.permissionNotAsked() {
            askingForPermission = true
        }
    }
}

/// The time of day Reminders fire at, as the phone writes times: "8:00 AM".
private var reminderTime: String {
    Calendar.current.date(bySettingHour: Reminder.hour, minute: 0, second: 0, of: .now)?
        .formatted(date: .omitted, time: .shortened) ?? ""
}

private enum RootTab: Hashable {
    case month
    case bills
}
