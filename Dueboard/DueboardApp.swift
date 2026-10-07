import HouseholdCore
import SwiftUI

@main
struct DueboardApp: App {
    @State private var opened = OpenedHousehold()
    @State private var reminders = ReminderNotifications()
    @State private var iCloud = ICloudAccount()

    var body: some Scene {
        WindowGroup {
            if let household = Binding($opened.household) {
                RootView(household: household, reminders: reminders)
                    .environment(\.householdReadAgain, opened.timesReadAgain)
                    .environment(iCloud)
            } else {
                ContentUnavailableView(
                    "Dueboard could not open its data",
                    systemImage: "exclamationmark.triangle",
                    description: Text(opened.openingError ?? "")
                )
            }
        }
    }
}

/// The Household as the store on this phone keeps it, read again whenever iCloud brings in
/// a change made on another device.
@MainActor @Observable
final class OpenedHousehold {
    var household: Household?
    private(set) var openingError: String?
    /// How many times the Household has been read again after a change from elsewhere, so
    /// screens that show something worked out from it can work it out again.
    private(set) var timesReadAgain = 0

    init() {
        do {
            let store = try CoreDataHouseholdStore()
            household = try Household.open(in: store, clock: .system)
            store.changedElsewhere = { [weak self, weak store] in store.map { self?.readAgain(from: $0) } }
        } catch {
            openingError = error.localizedDescription
        }
    }

    private func readAgain(from store: CoreDataHouseholdStore) {
        do {
            household = try Household.open(in: store, clock: .system)
            timesReadAgain += 1
        } catch {
            openingError = error.localizedDescription
            household = nil
        }
    }
}

extension EnvironmentValues {
    /// How many times the Household has been read again after a change from another device.
    @Entry var householdReadAgain = 0
}
