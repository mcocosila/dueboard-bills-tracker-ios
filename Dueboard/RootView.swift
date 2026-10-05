import HouseholdCore
import SwiftUI

/// The app's tabs: the Billing Month and the Bills. Keeps the phone's pending notifications
/// matching the reminder plan after launch, after every change and on coming back to the app,
/// asking for permission, with the reason, the first time there is a Reminder to send.
struct RootView: View {
    @Binding var household: Household
    @Bindable var reminders: ReminderNotifications
    @Environment(\.scenePhase) private var scenePhase
    @State private var tab = RootTab.month
    @State private var askingForPermission = false

    var body: some View {
        TabView(selection: $tab) {
            Tab("Month", systemImage: "calendar", value: .month) {
                MonthView(household: $household, monthToOpen: $reminders.monthToOpen)
            }
            Tab("Bills", systemImage: "list.bullet", value: .bills) {
                BillsView(household: $household)
            }
        }
        .task { await matchReminders() }
        .onChange(of: household.reminderPlan) { Task { await matchReminders() } }
        // Reminders whose time has passed drop out of the plan as the days go by.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await matchReminders() } }
        }
        .onChange(of: reminders.monthToOpen) { _, month in
            if month != nil { tab = .month }
        }
        .alert("Reminders", isPresented: $askingForPermission) {
            Button("Continue") { reminders.askPermission(thenMatch: household.reminderPlan) }
        } message: {
            Text("Dueboard reminds you at 9:00 when a Due becomes Due Soon, on its Due Date and the day after, until it is Paid.")
        }
    }

    /// Makes the pending notifications match the plan, first asking for permission when
    /// there is a Reminder to send and the phone has not been asked yet.
    private func matchReminders() async {
        let plan = household.reminderPlan
        if !plan.isEmpty, await reminders.permissionNotAsked() {
            askingForPermission = true
        } else {
            reminders.match(plan)
        }
    }
}

private enum RootTab: Hashable {
    case month
    case bills
}
